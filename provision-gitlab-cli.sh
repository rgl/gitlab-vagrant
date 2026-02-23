#!/bin/bash
set -eux

# create venv.
apt-get install -y python3-pip python3-venv
python3 -m venv --system-site-packages ~/.venv

# configure the shell to find the venv binaries.
echo 'export PATH="$HOME/.venv/bin:$PATH"' >>~/.bash_login
export PATH="$HOME/.venv/bin:$PATH"

# install.
# see https://pypi.org/project/python-gitlab/
# renovate: datasource=pypi depName=python-gitlab
python_gitlab_version='8.0.0'
python3 -m pip install "python-gitlab==$python_gitlab_version"
# NB on Windows, to trust the certificates in the Windows CA trust store
#    you also need to pip3 install python-certifi-win32.

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
