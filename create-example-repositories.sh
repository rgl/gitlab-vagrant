#!/bin/bash
set -euxo pipefail

source /vagrant/_include_gitlab_api.sh

# create the example group.
example_group_name='example'
example_group_id="$(gitlab-create-group $example_group_name | jq -r .id)"

# import some existing git repositories.
gitlab-create-project-and-import https://github.com/rgl/gitlab-ci-validate-jwt.git gitlab-ci-validate-jwt $example_group_id
gitlab-create-project-and-import https://github.com/rgl/gitlab-vagrant.git gitlab-vagrant $example_group_id
gitlab-create-project-and-import https://github.com/rgl/ubuntu-vagrant.git ubuntu-vagrant $example_group_id
gitlab-create-project-and-import https://github.com/rgl/example-dotnet-source-link.git example-dotnet-source-link $example_group_id
gitlab-create-project-and-import https://github.com/rgl/MailBounceDetector.git MailBounceDetector $example_group_id
gitlab-create-project-and-import https://github.com/rgl/HelloSeleniumWebDriver.git HelloSeleniumWebDriver $example_group_id
gitlab-create-project-and-import https://github.com/rgl/hello-puppeteer-windows-container.git hello-puppeteer-windows-container $example_group_id

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
# information about the ubuntu docker gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-ubuntu-docker $example_group_id
git clone https://root:password@$domain/$example_group_name/gitlab-runner-environment-info-ubuntu-docker.git gitlab-runner-environment-info-ubuntu-docker && cd gitlab-runner-environment-info-ubuntu-docker
# add a file with CR eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with carriage return (CR)\r3. This line ends with carriage return (CR)\r' >cr-eol-terminators.md
# add a file with LF eol terminators to see whether they are preserved.
printf '1. This line ends with line feed (LF)\n2. This line ends with line feed (LF)\n3. This line ends with line feed (LF)\n' >lf-eol-terminators.md
# add a file with CRLF eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return and line feed (CRLF)\r\n2. This line ends with carriage return and line feed (CRLF)\r\n3. This line ends with carriage return and line feed (CRLF)\r\n' >crlf-eol-terminators.md
# add a file with mixed eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with line feed (LF)\n3. This line ends with carriage return and line feed (CRLF)\r\n' >mixed-eol-terminators.md
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
    - apt-get update && apt-get install -y file procps
    - id
    - pwd
    - env | sort
    - mount | sort
    - ps axuww
    - file *-eol-terminators.md
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the windows powershell gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-windows-ps $example_group_id
git clone https://root:password@$domain/$example_group_name/gitlab-runner-environment-info-windows-ps.git gitlab-runner-environment-info-windows-ps && cd gitlab-runner-environment-info-windows-ps
# add a file with CR eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with carriage return (CR)\r3. This line ends with carriage return (CR)\r' >cr-eol-terminators.md
# add a file with LF eol terminators to see whether they are preserved.
printf '1. This line ends with line feed (LF)\n2. This line ends with line feed (LF)\n3. This line ends with line feed (LF)\n' >lf-eol-terminators.md
# add a file with CRLF eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return and line feed (CRLF)\r\n2. This line ends with carriage return and line feed (CRLF)\r\n3. This line ends with carriage return and line feed (CRLF)\r\n' >crlf-eol-terminators.md
# add a file with mixed eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with line feed (LF)\n3. This line ends with carriage return and line feed (CRLF)\r\n' >mixed-eol-terminators.md
# add the .gitlab-ci.yml file.
cat >.gitlab-ci.yml <<'EOF'
info:
  stage: test
  tags:
    - windows
    - powershell
  script:
    - |
        $FormatEnumerationLimit = -1
        function Write-Title($title) {
          Write-Output "#`n# $title`n#"
        }
    - |
        Write-Title 'Current user permissions'
        whoami.exe /all
    - |
        Write-Title 'Environment Variables'
        dir env: `
          | Sort-Object -Property Name `
          | Format-Table -AutoSize `
          | Out-String -Stream -Width ([int]::MaxValue) `
          | ForEach-Object {$_.TrimEnd()}
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the windows docker gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-windows-docker $example_group_id
git clone https://root:password@$domain/$example_group_name/gitlab-runner-environment-info-windows-docker.git gitlab-runner-environment-info-windows-docker && cd gitlab-runner-environment-info-windows-docker
# add a file with CR eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with carriage return (CR)\r3. This line ends with carriage return (CR)\r' >cr-eol-terminators.md
# add a file with LF eol terminators to see whether they are preserved.
printf '1. This line ends with line feed (LF)\n2. This line ends with line feed (LF)\n3. This line ends with line feed (LF)\n' >lf-eol-terminators.md
# add a file with CRLF eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return and line feed (CRLF)\r\n2. This line ends with carriage return and line feed (CRLF)\r\n3. This line ends with carriage return and line feed (CRLF)\r\n' >crlf-eol-terminators.md
# add a file with mixed eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with line feed (LF)\n3. This line ends with carriage return and line feed (CRLF)\r\n' >mixed-eol-terminators.md
# add the .gitlab-ci.yml file.
cat >.gitlab-ci.yml <<'EOF'
info:
  stage: test
  tags:
    - windows
    - docker
  script:
    - |
        $FormatEnumerationLimit = -1
        function Write-Title($title) {
          Write-Output "#`n# $title`n#"
        }
    - |
        Write-Title 'Current user permissions'
        whoami.exe /all
    - |
        Write-Title 'Environment Variables'
        dir env: `
          | Sort-Object -Property Name `
          | Format-Table -AutoSize `
          | Out-String -Stream -Width ([int]::MaxValue) `
          | ForEach-Object {$_.TrimEnd()}
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd
