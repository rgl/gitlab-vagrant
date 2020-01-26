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
echo 'Downloading Ubuntu Focal Fossa mini.iso. Be patient, this is about 74MB.'
wget -q http://archive.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/current/images/netboot/mini.iso
git lfs install
git lfs track '*.iso'
git add .gitattributes # NB git lfs uses this file to track the lfs file patterns.
git add *.iso
git commit -m 'Add netboot image'
git push
popd
