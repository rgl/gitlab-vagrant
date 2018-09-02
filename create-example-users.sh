#!/bin/bash
set -eux

source /vagrant/_include_gitlab_api.sh

email_domain=$(hostname --domain)

users=(
    'alice.doe  Alice Doe'
    'bob.doe    Bob Doe'
    'carol.doe  Carol Doe'
    'dave.doe   Dave Doe'
    'eve.doe    Eve Doe'
    'frank.doe  Frank Doe'
    'grace.doe  Grace Doe'
    'henry.doe  Henry Doe'
)
for user in "${users[@]}"; do
    username="$(echo "$user" | perl -n -e '/(.+?)\s+(.+)/ && print $1')"
    name="$(echo "$user" | perl -n -e '/(.+?)\s+(.+)/ && print $2')"

    gitlab-create-user "$username" "$name" "$username@$email_domain" password
done
