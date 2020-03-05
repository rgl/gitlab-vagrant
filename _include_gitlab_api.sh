domain=$(hostname --fqdn)

# e.g. gitlab-psql -t -c "select id,name from personal_access_tokens where user_id=1 and name='vagrant'"
function gitlab-psql {
    sudo -sHu gitlab-psql \
        /opt/gitlab/embedded/bin/psql \
        -h /var/opt/gitlab/postgresql \
        -d gitlabhq_production \
        "$@"
}

gitlab_private_token=$(cat /vagrant/tmp/gitlab-root-personal-access-token.txt)

function git {
    /opt/gitlab/embedded/bin/git "$@"
}

# see https://docs.gitlab.com/ce/api/README.html
function gitlab-api {
    local method=$1; shift
    local path=$1; shift
    http \
        --check-status \
        --ignore-stdin \
        $method \
        "https://$domain/api/v4$path" \
        "Private-Token:$gitlab_private_token" \
        "$@"
}

function gitlab-wait-for-ready {
    set +x
    echo 'Waiting for GitLab to be ready...'
    while true; do
        body=$(
            http \
                --ignore-stdin \
                GET \
                "https://$domain/api/v4/version" \
                "Private-Token:$gitlab_private_token")
        if jq -e . >/dev/null 2>&1 <<<"$body"; then
            version=$(jq -r .version <<<"$body")
            if [[ -n "$version" ]]; then
                echo "GitLab $version is ready!"
                break
            fi
        fi
        sleep 5
    done
    set -x
}

function gitlab-create-group {
    local name=$1

    local group="$(gitlab-api GET "/groups/$name?with_projects=false")"
    local id="$(echo "$group" | jq -r .id)"

    [ "$id" != 'null' ] && echo "$group" || gitlab-api POST /groups name=$name path=$name visibility=public
}

# see https://docs.gitlab.com/ce/api/groups.html#list-groups
function gitlab-get-groups {
    gitlab-api GET /groups
}

# see https://docs.gitlab.com/ce/api/members.html#add-a-member-to-a-group-or-project
function gitlab-add-user-to-all-groups {
    local user_id=$1
    local access_level=$2

    for id in $(gitlab-get-groups | jq '.[].id'); do
        gitlab-api POST "/groups/$id/members" \
            "user_id=$user_id" \
            "access_level=$access_level"
    done
}

function gitlab-create-project {
    local name="$1"
    local namespaceId="$2"
 
    # NB we need to retry this call because sometimes it fails with:
    #       HTTP 502 Bad Gateway
    #       GitLab is not responding
    set +x
    while true; do
        body="$(gitlab-api POST /projects "name=$name" "namespace_id=$namespaceId" visibility=public)"
        if jq -e . >/dev/null 2>&1 <<<"$body"; then
            id=$(jq -r .id <<<"$body")
            if [[ -n "$id" ]]; then
                echo "$body"
                break
            fi
        fi
        sleep 5
    done
    set -x
}

# creates a new GitLab project from an existing git repository.
# NB GitLab CE does not support mirroring a git repository.
function gitlab-create-project-and-import {
    local sourceGitUrl=$1
    local destinationProjectName=$2
    local destinationNamespaceId=$3
    local destinationNamespaceFullPath="$(gitlab-api GET /namespaces/$destinationNamespaceId | jq -r .full_path)"

    gitlab-create-project $destinationProjectName $destinationNamespaceId

    git \
        clone --mirror \
        $sourceGitUrl \
        $destinationProjectName

    pushd $destinationProjectName
    git \
        push --mirror \
        git@$domain:$destinationNamespaceFullPath/$destinationProjectName.git
    popd

    rm -rf $destinationProjectName
}

# see https://docs.gitlab.com/ce/api/users.html#user-creation
function gitlab-create-user {
    local username=$1
    local name=$2
    local email=$3
    local password=$4

    gitlab-api POST /users \
        "username=$username" \
        "name=$name" \
        "email=$email" \
        "password=$password" \
        skip_confirmation=true
}

# see https://docs.gitlab.com/ce/api/users.html#for-normal-users
function gitlab-get-user {
    local username=$1

    gitlab-api GET /users \
        "username=$username"
}

# see https://docs.gitlab.com/ce/api/users.html#create-an-impersonation-token
function gitlab-create-user-impersonation-token {
    local user_id="$1"
    local name="$2"
    local scopes="$3"

    # NB we need to retry this call because sometimes it fails with:
    #       HTTP 502 Bad Gateway
    #       GitLab is not responding
    set +x
    while true; do
        body="$(
            gitlab-api POST "/users/$user_id/impersonation_tokens" \
                "user_id=$username" \
                "name=$name" \
                "scopes:=$scopes"
        )"
        if jq -e . >/dev/null 2>&1 <<<"$body"; then
            token=$(jq -r .token <<<"$body")
            if [[ -n "$token" ]]; then
                echo "$body"
                break
            fi
        fi
        sleep 5
    done
    set -x
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
