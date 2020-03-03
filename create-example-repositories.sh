#!/bin/bash
set -eux

source /vagrant/_include_gitlab_api.sh

# create the example group.
example_group_name='example'
example_group_id="$(gitlab-create-group $example_group_name | jq -r .id)"

# import some existing git repositories.
gitlab-create-project-and-import https://github.com/rgl/gitlab-vagrant.git gitlab-vagrant $example_group_id
gitlab-create-project-and-import https://github.com/rgl/ubuntu-vagrant.git ubuntu-vagrant $example_group_id
gitlab-create-project-and-import https://github.com/rgl/example-dotnet-source-link.git example-dotnet-source-link $example_group_id
gitlab-create-project-and-import https://github.com/rgl/MailBounceDetector.git MailBounceDetector $example_group_id

# configure the git client.
git config --global user.name "Root Doe"
git config --global user.email root@$domain
git config --global push.default simple

# install git-lfs.
# see http://docs.gitlab.com/ce/workflow/lfs/manage_large_binaries_with_git_lfs.html
# see https://github.com/github/git-lfs/wiki/Installation
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
sudo apt-get install -y git-lfs

# create a new repository with git-lfs support.
#
# NB when you push to this GitLab server, the git repository will be stored
#    somewhere inside:
#       /var/opt/gitlab/git-data/repositories/
#    and the lfs objects inside:
#       /var/opt/gitlab/gitlab-rails/shared/lfs-objects/
pushd /tmp
gitlab-create-project use-git-lfs $example_group_id
export GIT_SSL_NO_VERIFY=true
git clone https://root:password@$domain/$example_group_name/use-git-lfs.git use-git-lfs && cd use-git-lfs
git lfs install
git lfs track '*.md'
echo 'This file is in lfs' >in-lfs.md
echo 'This file is in git repo db' >not-in-lfs.txt
git add .gitattributes # NB git lfs uses this file to track the lfs file patterns.
git add *
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info $example_group_id
git clone https://root:password@$domain/$example_group_name/gitlab-runner-environment-info.git gitlab-runner-environment-info && cd gitlab-runner-environment-info
# add a file with mixed eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with new line (LF)\n3. This line ends with carriage return and newline (CRLF)\r\n' >mixed-eol-terminators.md
# add the .gitlab-ci.yml file.
cat >.gitlab-ci.yml <<'EOF'
info:
  stage: test
  tags:
    - ubuntu
    - docker
  script:
    - cat /proc/self/cgroup | sort
    - cat /etc/os-release
    - uname -a
    - dpkg-query -W -f='${binary:Package}\n' | sort
    - apt-get update && apt-get install -y file
    - id
    - pwd
    - env | sort
    - mount | sort
    - ps axuww
    - file mixed-eol-terminators.md
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd
