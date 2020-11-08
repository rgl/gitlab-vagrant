#!/bin/bash
set -euxo pipefail

config_gitlab_fqdn=$(hostname --fqdn)
config_gitlab_ip=$1

# provision a recursve DNS server as a workaround for being able to access
# our custom domain from a windows container.
# see ../gitlab-ci-vagrant/windows/provision-gitlab-runner.ps1
# see http://www.thekelleys.org.uk/dnsmasq/docs/setup.html
# see http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
apt-get install -y dnsmasq
cat >/etc/dnsmasq.d/local.conf <<EOF
bind-interfaces
interface=eth1
no-hosts
host-record=$config_gitlab_fqdn,$config_gitlab_ip
EOF
systemctl restart dnsmasq
