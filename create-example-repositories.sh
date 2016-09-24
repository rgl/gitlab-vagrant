#!/bin/bash
set -eux

source /vagrant/_include_gitlab_api.sh

# import some existing git repositories.
gitlab-create-project-and-import https://github.com/rgl/gogs-vagrant.git gogs-vagrant
gitlab-create-project-and-import https://github.com/rgl/gitlab-vagrant.git gitlab-vagrant
gitlab-create-project-and-import https://github.com/rgl/ubuntu-vagrant.git ubuntu-vagrant
gitlab-create-project-and-import https://github.com/rgl/windows-domain-controller-vagrant.git windows-domain-controller-vagrant
gitlab-create-project-and-import https://github.com/rgl/selenium-server-windows-vagrant.git selenium-server-windows-vagrant
gitlab-create-project-and-import https://github.com/jkbrzt/httpie.git httpie
gitlab-create-project-and-import https://github.com/xenolf/lego lego
gitlab-create-project-and-import https://github.com/hlandau/acme acme
# NB we cannot import the certbot nor the boulder repository due to:
#   remote: GitLab: An unexpected error occurred (redis-cli returned 127).
# this seems to be a known problem (too many branches or tags).
# see https://gitlab.com/gitlab-org/gitlab-shell/issues/10
#gitlab-create-project-and-import https://github.com/certbot/certbot certbot
#gitlab-create-project-and-import https://github.com/letsencrypt/boulder.git boulder
# NB we cannot use the go repository, as it fails pushing to gitlab with things like:
#   ! [remote rejected] master -> master (pre-receive hook declined)
#   ! [remote rejected] weekly.2012-03-27 -> weekly.2012-03-27 (pre-receive hook declined)
#   ! [remote rejected] refs/users/00/5200/edit-1865/1 -> refs/users/00/5200/edit-1865/1 (pre-receive hook declined)
#gitlab-create-project-and-import https://github.com/golang/go.git go
# NB we cannot use the vagrant repository, as it fails pushing to gitlab with:
#   remote: error: object 3fb9bf325c24a1658261a6cf5e670d5b7d81119b: zeroPaddedFilemode: contains zero-padded file modes
#   remote: fatal: Error in object
#   error: pack-objects died of signal 13
#gitlab-create-project-and-import https://github.com/mitchellh/vagrant.git vagrant

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
gitlab-create-project use-git-lfs
export GIT_SSL_NO_VERIFY=true
git clone https://root:password@$domain/root/use-git-lfs.git use-git-lfs && cd use-git-lfs
echo 'Downloading Tears of Steel. Be patient, this is about 365MB.'
wget -q http://ftp.nluug.nl/pub/graphics/blender/demo/movies/ToS/tears_of_steel_720p.mov
git lfs install
git lfs track '*.mov'
git lfs track '*.mkv'
git lfs track '*.iso'
git add .gitattributes
git add *.mov
git commit -m 'Add Tears of Steel'
git push
popd
