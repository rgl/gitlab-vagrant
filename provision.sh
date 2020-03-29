#!/bin/bash
# see https://about.gitlab.com/install/#ubuntu
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#enable-https

set -eux

gitlab_version="${1:-12.9.1-ce.0}"; shift || true
domain=$(hostname --fqdn)
testing=true

apt-get update

apt-get install -y --no-install-recommends httpie

# install vim.
apt-get install -y --no-install-recommends vim
cat>/etc/vim/vimrc.local<<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
autocmd BufNewFile,BufRead Vagrantfile set ft=ruby
EOF

# set the initial shell history.
cat >~/.bash_history <<'EOF'
tail -f /var/log/gitlab/gitlab-rails/*.log
gitlab-ctl reconfigure
vim /etc/gitlab/gitlab.rb
vim /etc/hosts
netstat -antp
EOF

# install the gitlab deb repository.
apt-get install -y --no-install-recommends curl
wget -qO- https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash -ex

# install gitlab with the omnibus package.
apt-get install -y --no-install-recommends "gitlab-ce=$gitlab_version"

# create a self-signed certificate and add it to the global trusted list.
pushd /etc/ssl/private
openssl genrsa \
    -out $domain-keypair.pem \
    2048 \
    2>/dev/null
chmod 400 $domain-keypair.pem
openssl req -new \
    -sha256 \
    -subj "/CN=$domain" \
    -reqexts a \
    -config <(cat /etc/ssl/openssl.cnf
        echo "[a]
        subjectAltName=DNS:$domain
        ") \
    -key $domain-keypair.pem \
    -out $domain-csr.pem
openssl x509 -req -sha256 \
    -signkey $domain-keypair.pem \
    -extensions a \
    -extfile <(echo "[a]
        subjectAltName=DNS:$domain
        extendedKeyUsage=serverAuth
        ") \
    -days 365 \
    -in  $domain-csr.pem \
    -out $domain-crt.pem
cp $domain-crt.pem /usr/local/share/ca-certificates/$domain.crt
update-ca-certificates --verbose
popd

# configure gitlab to use it.
install -m 700 -o root -g root -d /etc/gitlab/ssl
ln -s /etc/ssl/private/$domain-keypair.pem /etc/gitlab/ssl/$domain.key
ln -s /etc/ssl/private/$domain-crt.pem /etc/gitlab/ssl/$domain.crt
sed -i -E "s,^(external_url\s+).+,\1'https://$domain'," /etc/gitlab/gitlab.rb
sed -i -E "s,^(\s*#\s*)?(nginx\['redirect_http_to_https'\]\s+).+,\2= true," /etc/gitlab/gitlab.rb

# show the changes we've made to gitlab.rb.
diff -u /opt/gitlab/etc/gitlab.rb.template /etc/gitlab/gitlab.rb || test $? = 1

# configure nginx status.
# see https://gitlab.com/gitlab-org/omnibus-gitlab/issues/2857
[ -n "$(which patch)" ] || apt-get install -y patch
patch --batch --quiet /etc/gitlab/gitlab.rb /vagrant/gitlab.rb-nginx-status.patch

# configure gitlab to use the dc.example.com Active Directory LDAP.
# NB this assumes you are running https://github.com/rgl/windows-domain-controller-vagrant.
if [ -f /vagrant/tmp/ExampleEnterpriseRootCA.der ]; then
    openssl x509 -inform der -in /vagrant/tmp/ExampleEnterpriseRootCA.der -out /usr/local/share/ca-certificates/ExampleEnterpriseRootCA.crt
    update-ca-certificates --verbose
    echo '192.168.56.2 dc.example.com' >>/etc/hosts
    patch --batch --quiet /etc/gitlab/gitlab.rb /vagrant/gitlab.rb-active-directory-ldap.patch
fi

# configure gitlab.
gitlab-ctl reconfigure

# set the gitlab root user password and create a personal access token.
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v12.9.1/app/models/user.rb
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v12.9.1/app/models/personal_access_token.rb
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v12.9.1/app/controllers/profiles/personal_access_tokens_controller.rb
gitlab-rails console -e production <<'EOF'
u = User.first
u.password_automatically_set = false
u.password = 'password'
u.password_confirmation = 'password'
u.save!
t = PersonalAccessToken.new({
    user: u,
    name: 'vagrant',
    scopes: ['api', 'read_user', 'sudo']})
t.save!
FileUtils.mkdir_p('/vagrant/tmp')
File.write(
    '/vagrant/tmp/gitlab-root-personal-access-token.txt',
    t.token)
EOF

# set the gitlab sign in page title and description.
# NB since gitlab 12.7 this can also be done with the appearance api.
#    see https://docs.gitlab.com/ee/api/appearance.html.
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v12.9.1/app/models/appearance.rb
gitlab-rails console -e production <<'EOF'
a = Appearance.first_or_initialize
a.title = 'GitLab Community Edition'
a.description = 'Sign in on the right or [explore the public projects](/explore/projects).'
a.save!
EOF

# include the gitlab api functions. 
apt-get install -y jq
source /vagrant/_include_gitlab_api.sh

# disable user signup.
gitlab-api PUT /application/settings signup_enabled:=false --check-status

# enable prometheus metrics.
# see https://gitlab.example.com/help/administration/monitoring/prometheus/gitlab_metrics#gitlab-prometheus-metrics
# see https://docs.gitlab.com/ce/api/settings.html
sed -i -E "s,^(\s*#\s*)?(prometheus\['listen_address'\]).+,\2 = '0.0.0.0:9090'," /etc/gitlab/gitlab.rb
gitlab-api PUT /application/settings prometheus_metrics_enabled:=true --check-status
gitlab-ctl reconfigure
gitlab-wait-for-ready

# configure postgres to allow the host (e.g. pgAdmin III) to easily connect.
if $testing; then
    echo 'host all all 10.10.9.0/24 trust' >> /var/opt/gitlab/postgresql/data/pg_hba.conf
    sed -i -E "s,^(\s*#\s*)?(listen_addresses\s+).+,\2= '*'," /var/opt/gitlab/postgresql/data/postgresql.conf
    gitlab-ctl restart postgresql
fi

# create artifacts that need to be shared with the other nodes.
mkdir -p /vagrant/tmp
pushd /vagrant/tmp
find \
    /etc/ssh \
    -name 'ssh_host_*_key.pub' \
    -exec sh -c "(echo -n '$domain '; cat {})" \; \
    >$domain.ssh_known_hosts
cp /etc/ssl/private/$domain-crt.pem .
openssl x509 -outform der -in $domain-crt.pem -out $domain-crt.der
gitlab-rails console -e production <<'EOF'
File.write(
    '/vagrant/tmp/gitlab-runners-registration-token.txt',
    Gitlab::CurrentSettings.current_application_settings.runners_registration_token)
EOF
popd
