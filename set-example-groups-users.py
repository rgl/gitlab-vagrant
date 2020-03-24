import gitlab

# this script will make sure the following usernames have the given role in all root groups (it ignores sub-groups).
# NB usernames are case sensitive.
users_role = {
    'alice.doe':    'Owner',
    'bob.doe':      'Maintainer',
    'carol.doe':    'Developer',
    'dave.doe':     'Reporter',
    'eve.doe':      'Guest',
}

access_levels = {
    'Guest':        gitlab.GUEST_ACCESS,
    'Reporter':     gitlab.REPORTER_ACCESS,
    'Developer':    gitlab.DEVELOPER_ACCESS,
    'Maintainer':   gitlab.MAINTAINER_ACCESS,
    'Owner':        gitlab.OWNER_ACCESS,
}
access_level_names = {v: k for k, v in access_levels.items()}

if True:
    # manually configure from a user token.
    import requests
    session = requests.Session()
    session.verify = '/vagrant/tmp/gitlab.example.com-crt.pem' # or just export the CA_BUNDLE environment variable.
    private_token = ''
    with open('/vagrant/tmp/gitlab-root-personal-access-token.txt', 'r') as f:
        private_token = f.read().strip()
    gl = gitlab.Gitlab('https://gitlab.example.com', session=session, private_token=private_token)
else:
    # automatically configure from configuration file (~/.python-gitlab.cfg or /etc/python-gitlab.cfg).
    gl = gitlab.Gitlab.from_config()

for group in gl.groups.list(all=True):
    print(f'group {group.full_path}')
    if '/' in group.full_path:
        # ignore sub-groups.
        continue
    missing_users = set(users_role.keys())
    for member in group.members.list(all=True):
        username = member.username
        user_role = users_role.get(username, None)
        if not user_role:
            continue
        missing_users.remove(username)
        expected_access_level = access_levels[users_role[username]]
        if member.access_level == expected_access_level:
            continue
        print(f'{group.full_path} group: updating user {username} role from {access_level_names[member.access_level]} to {user_role}...')
        member.access_level = expected_access_level
        member.save()
    for username in missing_users:
        user_role = users_role[username]
        access_level = access_levels[user_role]
        user = gl.users.list(username=username)[0]
        print(f'{group.full_path} group: adding user {username} as {user_role}...')
        group.members.create({
            'user_id': user.id,
            'access_level': access_level,
        })
