#!/bin/bash
set -eux

domain=$(hostname --fqdn)

# download.
artifact_url=https://github.com/rgl/gitlab-source-link-proxy/releases/download/v0.0.1/gitlab-source-link-proxy.tgz
artifact_sha=98a1e74e553c6f405e8c420fa714376b65501aa7532b16c64871a8812e40c179
wget -qO /tmp/gitlab-source-link-proxy.tgz $artifact_url
if [ "$(sha256sum /tmp/gitlab-source-link-proxy.tgz | awk '{print $1}')" != "$artifact_sha" ]; then
    echo "downloaded $artifact_url failed the checksum verification"
    exit 1
fi

# add the gitlab-source-link-proxy user.
groupadd --system gitlab-source-link-proxy
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup gitlab-source-link-proxy \
    --home /opt/gitlab-source-link-proxy \
    gitlab-source-link-proxy
install -d -o root -g gitlab-source-link-proxy -m 750 /opt/gitlab-source-link-proxy
install -d -o root -g gitlab-source-link-proxy -m 750 /opt/gitlab-source-link-proxy/bin

# create the service and start it.
tar xf /tmp/gitlab-source-link-proxy.tgz -C /opt/gitlab-source-link-proxy/bin
cat >/etc/systemd/system/gitlab-source-link-proxy.service <<EOF
[Unit]
Description=gitlab-source-link-proxy
After=network.target

[Service]
Type=simple
User=gitlab-source-link-proxy
Group=gitlab-source-link-proxy
ExecStart=/opt/gitlab-source-link-proxy/bin/gitlab-source-link-proxy --gitlab-base-url https://$domain
WorkingDirectory=/opt/gitlab-source-link-proxy
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF
systemctl enable gitlab-source-link-proxy
systemctl start gitlab-source-link-proxy

# configure gitlab nginx.
patch --batch --quiet \
    /var/opt/gitlab/nginx/conf/gitlab-http.conf \
    /vagrant/gitlab-http.conf-gitlab-source-link-proxy.patch
gitlab-ctl restart nginx

# wait for gitlab to be ready.
source /vagrant/_include_gitlab_api.sh
gitlab-wait-for-ready

# try it.
http -v --check-status --ignore-stdin \
    https://root:password@$domain/example/ubuntu-vagrant/raw/master/.gitignore \
    User-Agent:SourceLink
