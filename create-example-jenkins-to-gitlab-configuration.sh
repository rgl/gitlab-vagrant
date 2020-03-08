#!/bin/bash
set -eux

source /vagrant/_include_gitlab_api.sh

email_domain=$(hostname --domain)
username='jenkins'
name='Jenkins'

# create and add the jenkins user as a Developer member to all groups.
user_json="$(gitlab-create-user "$username" "$name" "$username@$email_domain" password)"
user_id="$(echo "$user_json" | jq '.id')"
gitlab-add-user-to-all-groups "$user_id" '30' # 30 => Developer

# create a impersonation token.
token_json="$(gitlab-create-user-impersonation-token "$user_id" 'jenkins' '["api"]')"
echo "$token_json" | jq -j '.token' >/vagrant/tmp/gitlab-jenkins-impersonation-token.txt

# allow requests to the local network from hooks and services.
gitlab-api PUT /application/settings allow_local_requests_from_hooks_and_services:=true --check-status
