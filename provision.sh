#!/bin/bash
# see https://about.gitlab.com/downloads/#ubuntu1604
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#enable-https

set -eux

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
apt-get install -y --no-install-recommends gitlab-ce

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

# set the gitlab root user password.
gitlab-rails console production <<'EOF'
u = User.first
u.password_automatically_set = false
u.password = 'password'
u.password_confirmation = 'password'
u.save!
EOF

# include the gitlab api functions. 
source /vagrant/_include_gitlab_api.sh

# disable user signup.
gitlab-api PUT /application/settings signup_enabled:=false

# configure postgres to allow the host (e.g. pgAdmin III) to easily connect.
if $testing; then
    echo 'host all all 192.168.33.0/24 trust' >> /var/opt/gitlab/postgresql/data/pg_hba.conf
    sed -i -E "s,^(\s*#\s*)?(listen_addresses\s+).+,\2= '*'," /var/opt/gitlab/postgresql/data/postgresql.conf
    gitlab-ctl restart postgresql
fi

# create some example repositories.
bash /vagrant/create-example-repositories.sh

# see the gitlab services status.
gitlab-ctl status

# show software versions.
dpkg-query --showformat '${Package} ${Version}\n' --show gitlab-ce
/opt/gitlab/embedded/bin/git --version
/opt/gitlab/embedded/bin/ruby -v
gitlab-rails --version
gitlab-psql --version
/opt/gitlab/embedded/bin/redis-server --version
/opt/gitlab/embedded/sbin/nginx -v
