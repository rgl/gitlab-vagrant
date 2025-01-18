#!/bin/bash
set -euxo pipefail

domain=$(hostname --fqdn)

# see the gitlab services status.
while ! gitlab-ctl status; do sleep 5; done

# show the gitlab environment info.
gitlab-rake gitlab:env:info

# show software versions.
dpkg-query --showformat '${Package} ${Version}\n' --show gitlab-ce
/opt/gitlab/embedded/bin/git --version
/opt/gitlab/embedded/bin/ruby -v
gitlab-rails --version
gitlab-psql --version
/opt/gitlab/embedded/bin/redis-server --version
/opt/gitlab/embedded/sbin/nginx -v

# list projects using the gitlab-cli tool.
echo 'GitLab projects:'
gitlab -o yaml -f id,web_url project list --get-all

# try the source-link-proxy.
http -v --check-status --ignore-stdin \
    https://root:HeyH0Password@$domain/example/ubuntu-vagrant/raw/master/.gitignore \
    User-Agent:SourceLink

# show GitLab address and root credentials.
echo "GitLab is running at https://$domain"
echo 'Sign in with the root user and the HeyH0Password password'
