#!/bin/bash
set -eux

domain=$(hostname --fqdn)

# download.
artifact_url=https://github.com/rgl/gitlab-source-link-proxy/releases/download/v0.0.2/gitlab-source-link-proxy_0.0.2_linux_amd64.tar.gz
artifact_sha=e0d8001feb5ca27cd56486bc103139a192e3e22f21e2ec5d34108637b9f9a133
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
tar xf /tmp/gitlab-source-link-proxy.tgz \
    --owner root \
    --group root \
    --no-same-owner \
    -C /opt/gitlab-source-link-proxy/bin
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
