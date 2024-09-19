#!/bin/bash
set -eux

# install.
# see https://pypi.org/project/python-gitlab/
# renovate: datasource=pypi depName=python-gitlab
python_gitlab_version='4.11.1'
apt-get install -y python3-pip
python3 -m pip install "python-gitlab==$python_gitlab_version"
# NB on Windows, to trust the certificates in the Windows CA trust store
#    you also need to pip3 install python-certifi-win32.

# configure the shell to find the binaries.
echo 'export PATH="$PATH:~/.local/bin"' >>~/.bashrc
export PATH="$PATH:~/.local/bin"

# configure gitlab-cli with the root token.
cat >~/.python-gitlab.cfg <<EOF
[global]
default = gitlab.example.com
ssl_verify = true
timeout = 5

[gitlab.example.com]
url = https://gitlab.example.com
private_token = $(cat /vagrant/tmp/gitlab-root-personal-access-token.txt)
api_version = 4
EOF
chmod 600 ~/.python-gitlab.cfg
