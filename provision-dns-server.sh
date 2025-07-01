#!/bin/bash
set -euxo pipefail

config_domain="$(hostname --domain)"
config_gitlab_fqdn="$(hostname --fqdn)"
config_gitlab_ip="$1"
config_vault_fqdn="$2"
config_vault_ip="$3"
config_ubuntu_runner_fqdn="$4"
config_ubuntu_runner_ip="$5"
config_incus_runner_fqdn="$6"
config_incus_runner_ip="$7"
config_lxd_runner_fqdn="$8"
config_lxd_runner_ip="$9"
config_windows_runner_fqdn="${10}"
config_windows_runner_ip="${11}"

# provision a recursive DNS server for our custom domain. it will be used by
# this and the runner machines.
# see ../gitlab-ci-vagrant/windows/provision-gitlab-runner.ps1
# see http://www.thekelleys.org.uk/dnsmasq/docs/setup.html
# see http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html
apt-get install -y dnsmasq
cat >/etc/dnsmasq.d/local.conf <<EOF
bind-interfaces
interface=eth1
no-hosts
auth-zone=$config_domain
auth-server=$config_domain
host-record=$config_gitlab_fqdn,$config_gitlab_ip
host-record=$config_vault_fqdn,$config_vault_ip
host-record=$config_ubuntu_runner_fqdn,$config_ubuntu_runner_ip
host-record=$config_incus_runner_fqdn,$config_incus_runner_ip
host-record=$config_lxd_runner_fqdn,$config_lxd_runner_ip
host-record=$config_windows_runner_fqdn,$config_windows_runner_ip
EOF
systemctl restart dnsmasq

# configure systemd to use dnsmasq when resolving $config_domain
# domain names.
install -d /etc/systemd/resolved.conf.d
cat >/etc/systemd/resolved.conf.d/local.conf <<EOF
[Resolve]
DNS=127.0.0.1
Domains=~$config_domain
EOF
systemctl restart systemd-resolved
resolvectl status
