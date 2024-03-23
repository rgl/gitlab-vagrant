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
git clone https://root:HeyH0Password@$domain/$example_group_name/use-git-lfs.git use-git-lfs && cd use-git-lfs
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
# information about the ubuntu shell gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-ubuntu-shell $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-ubuntu-shell.git gitlab-runner-environment-info-ubuntu-shell && cd gitlab-runner-environment-info-ubuntu-shell
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
default:
  before_script:
    # show the shell executable.
    - echo "$SHELL"
    # show the shell command line arguments.
    - cat "/proc/$$/cmdline" | tr \\0 \\n
    # enable the shell strict mode.
    - set -euo pipefail
    # show the shell options.
    - set -o
info:
  tags:
    - ubuntu
    - shell
  script:
    - cat /proc/self/cgroup | sort
    - cat /etc/os-release
    - uname -a
    - dpkg-query -W -f='${binary:Package}\n' | sort
    - id
    - pwd
    - env | sort
    - mount | sort
    - ps axuww
    - file *-eol-terminators.md
docker-info:
  tags:
    - ubuntu
    - shell
  script:
    - docker compose version
    - docker info
    - docker run --rm hello-world
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the ubuntu docker gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-ubuntu-docker $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-ubuntu-docker.git gitlab-runner-environment-info-ubuntu-docker && cd gitlab-runner-environment-info-ubuntu-docker
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
default:
  before_script:
    # show the shell executable.
    - echo "$SHELL"
    # show the shell command line arguments.
    - cat "/proc/$$/cmdline" | tr \\0 \\n
    # enable the shell strict mode.
    - set -euo pipefail
    # show the shell options.
    - set -o
info:
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
# information about the ubuntu incus gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-ubuntu-incus $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-ubuntu-incus.git gitlab-runner-environment-info-ubuntu-incus && cd gitlab-runner-environment-info-ubuntu-incus
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
default:
  before_script:
    # show the shell executable.
    - echo "$SHELL"
    # show the shell command line arguments.
    - cat "/proc/$$/cmdline" | tr \\0 \\n
    # enable the shell strict mode.
    - set -euo pipefail
    # show the shell options.
    - set -o
info:
  tags:
    - ubuntu
    - incus
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
docker-info:
  tags:
    - ubuntu
    - incus
  script:
    - docker compose version
    - docker info
    - docker run --rm hello-world
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the ubuntu lxd gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-ubuntu-lxd $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-ubuntu-lxd.git gitlab-runner-environment-info-ubuntu-lxd && cd gitlab-runner-environment-info-ubuntu-lxd
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
default:
  before_script:
    # show the shell executable.
    - echo "$SHELL"
    # show the shell command line arguments.
    - cat "/proc/$$/cmdline" | tr \\0 \\n
    # enable the shell strict mode.
    - set -euo pipefail
    # show the shell options.
    - set -o
info:
  tags:
    - ubuntu
    - lxd
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
docker-info:
  tags:
    - ubuntu
    - lxd
  script:
    - docker compose version
    - docker info
    - docker run --rm hello-world
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the k8s gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-k8s $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-k8s.git gitlab-runner-environment-info-k8s && cd gitlab-runner-environment-info-k8s
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
default:
  before_script:
    # show the shell executable.
    - echo "$SHELL"
    # show the shell command line arguments.
    - cat "/proc/$$/cmdline" | tr \\0 \\n
    # enable the shell strict mode.
    - set -euo pipefail
    # show the shell options.
    - set -o
info:
  tags:
    - k8s
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
# information about the windows pwsh gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-windows-pwsh $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-windows-pwsh.git gitlab-runner-environment-info-windows-pwsh && cd gitlab-runner-environment-info-windows-pwsh
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
default:
  before_script:
    - |
      $FormatEnumerationLimit = -1
      function Write-Title($title) {
        Write-Output "#`n# $title`n#"
      }
    # wrap the docker command (to make sure this script aborts when it fails).
    - |
      function docker {
        docker.exe @Args | Out-String -Stream -Width ([int]::MaxValue)
        if ($LASTEXITCODE) {
          throw "$(@('docker')+$Args | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
        }
      }
info:
  tags:
    - windows
    - pwsh
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
    - |
      Write-Title 'PowerShell Info'
      $PSVersionTable
docker-info:
  tags:
    - windows
    - pwsh
  script:
    - |
      Write-Title 'Docker Compose Version'
      docker compose version
    - |
      Write-Title 'Docker Info'
      docker info
    - |
      Write-Title 'Docker hello-world'
      docker run --rm hello-world
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd

# create a new repository with a .gitlab-ci.yml file to show
# information about the windows docker gitlab-runner environment.
pushd /tmp
gitlab-create-project gitlab-runner-environment-info-windows-docker $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-info-windows-docker.git gitlab-runner-environment-info-windows-docker && cd gitlab-runner-environment-info-windows-docker
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

# create a new repository with a .gitlab-ci.yml file to test building a docker
# image on the windows docker gitlab-runner environment.
# NB as of docker 24.0.7, --chown does not work in windows containers.
#    see https://github.com/rgl/windows-dockerfile-copy-with-chown-test
#    see https://github.com/moby/moby/issues/35507
#    see https://github.com/moby/moby/issues/41776
pushd /tmp
gitlab-create-project gitlab-runner-environment-build-windows-container-image $example_group_id
git clone https://root:HeyH0Password@$domain/$example_group_name/gitlab-runner-environment-build-windows-container-image.git gitlab-runner-environment-build-windows-container-image && cd gitlab-runner-environment-build-windows-container-image
# add a file with CR eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with carriage return (CR)\r3. This line ends with carriage return (CR)\r' >cr-eol-terminators.md
# add a file with LF eol terminators to see whether they are preserved.
printf '1. This line ends with line feed (LF)\n2. This line ends with line feed (LF)\n3. This line ends with line feed (LF)\n' >lf-eol-terminators.md
# add a file with CRLF eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return and line feed (CRLF)\r\n2. This line ends with carriage return and line feed (CRLF)\r\n3. This line ends with carriage return and line feed (CRLF)\r\n' >crlf-eol-terminators.md
# add a file with mixed eol terminators to see whether they are preserved.
printf '1. This line ends with carriage return (CR)\r2. This line ends with line feed (LF)\n3. This line ends with carriage return and line feed (CRLF)\r\n' >mixed-eol-terminators.md
# add test script.
cat >test.ps1 <<'EOF'
function Write-Title($title) {
    Write-Output "`n#`n# $title`n#`n"
}

Write-Title "chown-guests.txt"
Get-Acl chown-guests.txt | Format-List

Write-Title "chown-administrator.txt"
Get-Acl chown-administrator.txt | Format-List

Write-Title "chown-containeruser.txt"
Get-Acl chown-containeruser.txt | Format-List
EOF
# add test files.
echo 'Administrator' >chown-administrator.txt
echo 'Guests' >chown-guests.txt
echo 'ContainerUser' >chown-containeruser.txt
# add Dockefile.
cat >Dockerfile <<'EOF'
# escape=`
#FROM mcr.microsoft.com/windows/nanoserver:ltsc2022
FROM mcr.microsoft.com/powershell:7.2-nanoserver-ltsc2022
ENTRYPOINT ["pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; $FormatEnumerationLimit = -1; "]
SHELL      ["pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; $FormatEnumerationLimit = -1; "]
RUN mkdir C:\test | Out-Null
WORKDIR C:\test
COPY test.ps1 ./
COPY --chown=Guests chown-guests.txt ./
COPY --chown=Administrator chown-administrator.txt ./
COPY --chown=ContainerUser chown-containeruser.txt ./
CMD ["./test.ps1"]
EOF
# add the .gitlab-ci.yml file.
cat >.gitlab-ci.yml <<'EOF'
default:
  before_script:
    # enable strict mode and fail the job when there is an unhandled exception.
    - |
      Set-StrictMode -Version Latest
      $FormatEnumerationLimit = -1
      $ErrorActionPreference = 'Stop'
      $ProgressPreference = 'SilentlyContinue'
      trap {
        Write-Host "ERROR: $_"
        ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
        ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
        Exit 1
      }
    # wrap the docker command (to make sure this script aborts when it fails).
    - |
      function docker {
        docker.exe @Args | Out-String -Stream -Width ([int]::MaxValue)
        if ($LASTEXITCODE) {
          throw "$(@('docker')+$Args | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
        }
      }
build:
  tags:
    - windows
    - pwsh
  script:
    - |
      docker compose version
    - |
      docker info
    - |
      docker build --iidfile image-id.txt .
      $imageId = Get-Content -Raw image-id.txt
    - |
      docker run --rm --tty $imageId
EOF
git add * .gitlab-ci.yml
git commit -m 'init'
git push
popd
