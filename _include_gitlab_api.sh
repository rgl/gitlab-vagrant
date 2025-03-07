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

# see https://docs.gitlab.com/api/rest/
function gitlab-api {
    local method=$1; shift
    local path=$1; shift
    http \
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

    local group="$(gitlab-api GET "/groups/$name?with_projects=false" --check-status)"
    local id="$(echo "$group" | jq -r .id)"

    [ "$id" != 'null' ] && echo "$group" || gitlab-api POST /groups name=$name path=$name visibility=private --check-status
}

# see https://docs.gitlab.com/api/groups/#list-groups
function gitlab-get-groups {
    gitlab-api GET /groups --check-status
}

# see https://docs.gitlab.com/api/members/#add-a-member-to-a-group-or-project
function gitlab-add-user-to-all-groups {
    local user_id=$1
    local access_level=$2

    for id in $(gitlab-get-groups | jq '.[].id'); do
        gitlab-api POST "/groups/$id/members" \
            "user_id=$user_id" \
            "access_level=$access_level" \
            --check-status
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
        body="$(gitlab-api POST /projects "name=$name" "namespace_id=$namespaceId" visibility=private)"
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
    local destinationNamespaceFullPath="$(gitlab-api GET /namespaces/$destinationNamespaceId --check-status | jq -r .full_path)"

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

# see https://docs.gitlab.com/api/users/#create-a-user
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
        skip_confirmation=true \
        --check-status
}

# see https://docs.gitlab.com/api/users/#as-a-regular-user
function gitlab-get-user {
    local username=$1

    gitlab-api GET /users \
        "username=$username" \
        --check-status
}

# see https://docs.gitlab.com/api/user_tokens/#create-an-impersonation-token
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

# trust our own SSH server.
if [ -z "$(ssh-keygen -F $domain 2>/dev/null)" ]; then
    install -d -m 700 ~/.ssh
    ssh-keyscan -H $domain >> ~/.ssh/known_hosts
fi

# generate a new ssh key for the current user account and add it to gitlab.
# NB the public keys should end-up in /var/opt/gitlab/.ssh/authorized_keys.
#    NB that happens asynchronously via a sidekick job, as such, it might
#       not be immediately visible.
# see https://docs.gitlab.com/user/ssh/
# see https://docs.gitlab.com/administration/raketasks/maintenance/#rebuild-authorized_keys-file
# TODO consider switching to https://docs.gitlab.com/administration/operations/fast_ssh_key_lookup/
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -b 2048 -C "$USER@$domain" -N ''
    gitlab-api POST /user/keys "title=$USER@$domain" key=@~/.ssh/id_rsa.pub --check-status

    # force the update of the authorized_keys to workaround the
    # bug introduced in 12.9.0.
    # NB this also happens when adding the key in the UI.
    # see https://gitlab.com/gitlab-org/gitlab/-/issues/212297
    yes yes | gitlab-rake gitlab:shell:setup

    # wait for the key to be asynchronously added to the authorized_keys file.
    # NB this just checks whether the file length is above 500B and
    #    assumes the ssh was successfully added, which is enough for
    #    this use-case.
    while [ "$(stat --printf="%s" /var/opt/gitlab/.ssh/authorized_keys)" -le 500 ]; do
        sleep 5
    done

    # test the ssh connection.
    # NB this will eventually show "Welcome to GitLab, @root!"
    ssh -o BatchMode=yes -Tv git@$domain </dev/null
fi
