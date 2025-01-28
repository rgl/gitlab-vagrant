#!/bin/bash
set -euxo pipefail

config_gitlab_fqdn="$(hostname --fqdn)"
config_gitlab_ip="$1"
config_ubuntu_runner_fqdn="$2"
config_ubuntu_runner_ip="$3"
config_incus_runner_fqdn="$4"
config_incus_runner_ip="$5"
config_lxd_runner_fqdn="$6"
config_lxd_runner_ip="$7"
config_windows_runner_fqdn="$8"
config_windows_runner_ip="$9"

# provision a recursive DNS server as a workaround for being able to access
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
host-record=$config_ubuntu_runner_fqdn,$config_ubuntu_runner_ip
host-record=$config_incus_runner_fqdn,$config_incus_runner_ip
host-record=$config_lxd_runner_fqdn,$config_lxd_runner_ip
host-record=$config_windows_runner_fqdn,$config_windows_runner_ip
EOF
systemctl restart dnsmasq
