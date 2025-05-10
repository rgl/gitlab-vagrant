#!/bin/bash
# see https://about.gitlab.com/install/#ubuntu
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md
# see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/doc/settings/nginx.md#enable-https

set -eux

gitlab_version="${1:-17.11.2-ce.0}"; shift || true
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
apt-get install -y --no-install-recommends "gitlab-ce=$gitlab_version"

# configure the gitlab certificate.
install -m 700 -o root -g root -d /etc/gitlab/ssl
ln -s "/etc/ssl/private/$domain-key.pem" "/etc/gitlab/ssl/$domain.key"
ln -s "/etc/ssl/private/$domain-crt.pem" "/etc/gitlab/ssl/$domain.crt"
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

# set the gitlab root user password and create a personal access token.
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v17.11.2/app/models/user.rb
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v17.11.2/app/models/personal_access_token.rb
gitlab-rails runner -e production - <<'EOF'
u = User.first
u.password_automatically_set = false
u.password = 'HeyH0Password'
u.password_confirmation = 'HeyH0Password'
u.save!
t = PersonalAccessToken.new({
    user: u,
    name: 'vagrant',
    scopes: ['api', 'read_user', 'sudo'],
    expires_at: PersonalAccessToken::MAX_PERSONAL_ACCESS_TOKEN_LIFETIME_IN_DAYS.days.from_now})
t.save!
File.write(
    '/tmp/gitlab-root-personal-access-token.txt',
    t.token)
EOF
mkdir -p /vagrant/tmp
mv /tmp/gitlab-root-personal-access-token.txt /vagrant/tmp

# set the gitlab sign in page title and description.
# NB since gitlab 12.7 this can also be done with the appearance api.
#    see https://docs.gitlab.com/api/appearance/.
# see https://gitlab.com/gitlab-org/gitlab-foss/blob/v17.11.2/app/models/appearance.rb
gitlab-rails runner -e production - <<'EOF'
a = Appearance.first_or_initialize
a.title = 'GitLab Community Edition'
a.description = 'Sign in on the right or [explore the public projects](/explore/projects).'
a.save!
EOF

# include the gitlab api functions.
apt-get install -y jq
source /vagrant/_include_gitlab_api.sh

# disable user signup.
gitlab-api PUT /application/settings signup_enabled:=false --check-status

# disable the creation of public groups and repositories.
# NB administrators can still create them, but regular users cannot.
# see https://docs.gitlab.com/user/public_access/
# see https://docs.gitlab.com/api/settings/
gitlab-api PUT /application/settings restricted_visibility_levels:='["public"]' --check-status --print ''

# set the maximum artifacts size to 1 GB (default is 100 MB; gitlab.com default is 1 GB).
# NB this can be set at the instance level (like in this example), at group level, and project level.
# NB this can also be set in the UI at Admin Area | CI/CD | Continuous Integration and Deployment | Maximum artifacts size (MB).
# see https://docs.gitlab.com/api/settings/
# see https://gitlab.example.com/admin/application_settings/ci_cd
# see https://gitlab.example.com/help/user/admin_area/settings/continuous_integration#maximum-artifacts-size
# see https://gitlab.example.com/help/user/gitlab_com/index.md#gitlab-cicd
gitlab-api PUT /application/settings max_artifacts_size:=1024 --check-status --print ''

# do not keep the latest artifacts for all jobs in the latest successful pipelines.
# NB all artifacts will be erased after they expire.
gitlab-api PUT /application/settings keep_latest_artifact:=false --check-status --print ''

# set default artifacts expiration to 3d (default is 30d; gitlab.com default is 30d).
# see https://gitlab.example.com/help/user/admin_area/settings/continuous_integration#default-artifacts-expiration
gitlab-api PUT /application/settings default_artifacts_expire_in=3d --check-status --print ''

# archive the jobs after 3d (default is to never archive them; gitlab.com default is 3mo).
# see https://gitlab.example.com/help/user/admin_area/settings/continuous_integration#archive-jobs
gitlab-api PUT /application/settings archive_builds_in_human_readable=3d --check-status --print ''

# enable prometheus metrics.
# see https://gitlab.example.com/help/administration/monitoring/prometheus/gitlab_metrics#gitlab-prometheus-metrics
# see https://docs.gitlab.com/api/settings/
sed -i -E "s,^(\s*#\s*)?(prometheus\['listen_address'\]).+,\2 = '0.0.0.0:9090'," /etc/gitlab/gitlab.rb
gitlab-api PUT /application/settings prometheus_metrics_enabled:=true --check-status
gitlab-ctl reconfigure
gitlab-wait-for-ready

# configure postgres to allow the host (e.g. pgAdmin III) to easily connect.
if $testing; then
    echo 'host all all 10.10.9.0/24 trust' >> /var/opt/gitlab/postgresql/data/pg_hba.conf
    sed -i -E "s,^(\s*#\s*)?(listen_addresses\s+).+,\2= '*'," /var/opt/gitlab/postgresql/data/postgresql.conf
    gitlab-ctl restart postgresql
fi

# create artifacts that need to be shared with the other nodes.
mkdir -p /vagrant/tmp
pushd /vagrant/tmp
find \
    /etc/ssh \
    -name 'ssh_host_*_key.pub' \
    -exec sh -c "(echo -n '$domain '; cat {})" \; \
    >$domain.ssh_known_hosts
rm -f gitlab-runner-authentication-token-*.json
# register the ubuntu 22.04 shell runner.
# see https://docs.gitlab.com/api/runners/#create-a-runner
# see https://docs.gitlab.com/api/users/#create-a-runner-linked-to-a-user
# see https://docs.gitlab.com/runner/executors/shell/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='shell,linux,ubuntu,ubuntu-22.04' \
    description='Shell / Ubuntu 22.04' \
    --check-status \
    >gitlab-runner-authentication-token-ubuntu-22.04-shell.json
# register the ubuntu 22.04 docker runner.
# see https://docs.gitlab.com/runner/executors/docker/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='docker,linux,ubuntu,ubuntu-22.04' \
    description='Docker / Ubuntu 22.04' \
    --check-status \
    >gitlab-runner-authentication-token-ubuntu-22.04-docker.json
# register the ubuntu 22.04 incus runner.
# see https://docs.gitlab.com/runner/executors/custom/
# see https://docs.gitlab.com/runner/executors/custom_examples/lxd/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='incus,linux,ubuntu,ubuntu-22.04' \
    description='Incus / Ubuntu 22.04' \
    --check-status \
    >gitlab-runner-authentication-token-ubuntu-22.04-incus.json
# register the ubuntu 22.04 lxd runner.
# see https://docs.gitlab.com/runner/executors/custom/
# see https://docs.gitlab.com/runner/executors/custom_examples/lxd/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='lxd,linux,ubuntu,ubuntu-22.04' \
    description='LXD / Ubuntu 22.04' \
    --check-status \
    >gitlab-runner-authentication-token-ubuntu-22.04-lxd.json
# register the k3s k8s runner.
# see https://docs.gitlab.com/runner/executors/kubernetes/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='k3s,k8s' \
    description='K3S / Kubernetes' \
    --check-status \
    >gitlab-runner-authentication-token-kubernetes-k3s.json
# register the windows 2022 shell runner.
# see https://docs.gitlab.com/runner/executors/shell/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='pwsh,shell,vs2022,windows,windows-2022' \
    description='Shell / Windows 2022' \
    --check-status \
    >gitlab-runner-authentication-token-windows-2022-shell.json
# register the windows 2022 docker runner.
# see https://docs.gitlab.com/runner/executors/docker/
gitlab-api POST /user/runners \
    runner_type=instance_type \
    tag_list='docker,windows,windows-2022' \
    description='Docker / Windows 2022' \
    --check-status \
    >gitlab-runner-authentication-token-windows-2022-docker.json
popd
