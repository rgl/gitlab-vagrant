#!/bin/bash
# see https://about.gitlab.com/downloads/#ubuntu1604
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#enable-https

set -eux

domain=$(hostname --fqdn)
testing=true

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

# configure postgres to allow the host (e.g. pgAdmin III) to easily connect.
if $testing; then
    echo 'host all all 192.168.33.0/24 trust' >> /var/opt/gitlab/postgresql/data/pg_hba.conf
    sed -i -E "s,^(\s*#\s*)?(listen_addresses\s+).+,\2= '*'," /var/opt/gitlab/postgresql/data/postgresql.conf
    gitlab-ctl restart postgresql
fi

# import some example repositories.
bash /vagrant/import-repositories.sh

# see the gitlab services status.
gitlab-ctl status
