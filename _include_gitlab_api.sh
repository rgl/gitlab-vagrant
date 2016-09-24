domain=$(hostname --fqdn)

function gitlab-psql {
    sudo -sHu gitlab-psql \
        /opt/gitlab/embedded/bin/psql \
        -h /var/opt/gitlab/postgresql \
        -d gitlabhq_production \
        "$@"
}

gitlab_private_token=$(gitlab-psql -t -c 'select authentication_token from users where id=1')

function git {
    /opt/gitlab/embedded/bin/git "$@"
}

function gitlab-api {
    local method=$1; shift
    local path=$1; shift
    http \
        --check-status \
        --ignore-stdin \
        $method \
        "https://$domain/api/v3$path" \
        "PRIVATE-TOKEN:$gitlab_private_token" \
        "$@"
}

function gitlab-create-project {
    local name=$1

    gitlab-api POST /projects name=$name public:=true
}

# creates a new GitLab project from an existing git repository.
# NB GitLab CE does not support mirroring a git repository.
function gitlab-create-project-and-import {
    local sourceGitUrl=$1
    local destinationProjectName=$2

    gitlab-create-project $destinationProjectName

    git \
        clone --mirror \
        $sourceGitUrl \
        $destinationProjectName

    pushd $destinationProjectName
    git \
        push --mirror \
        git@$domain:root/$destinationProjectName.git
    popd

    rm -rf $destinationProjectName
}

# generate a new ssh key for the current user account and add it to gitlab.
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -b 2048 -C "$USER@$domain" -N ''
    gitlab-api POST /user/keys "title=$USER@$domain" key=@~/.ssh/id_rsa.pub
fi

# trust our own SSH server.
if [ -z "$(ssh-keygen -F $domain 2>/dev/null)" ]; then
    ssh-keyscan -H $domain >> ~/.ssh/known_hosts
fi
