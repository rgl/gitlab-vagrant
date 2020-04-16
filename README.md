# Environment

This [vagrant](https://www.vagrantup.com/) environment configures a basic [GitLab Community Edition](https://gitlab.com/gitlab-org/gitlab-foss) installation using the [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab) package.

[Nginx](http://nginx.org/en/) ([HTTP/2](https://en.wikipedia.org/wiki/HTTP/2) enabled) is configured with a self-signed certificate at:

> https://gitlab.example.com/

[PostgreSQL](http://www.postgresql.org/) is configured to allow (and trust) any connection from the host. For example, you can use [pgAdmin III](http://www.pgadmin.org/) with these settings:

    Host: gitlab.example.com
    Port: 5432
    Maintenance DB: postgres
    Username: gitlab-psql

GitLab is also configured to use the optional `ldaps://dc.example.com` Active Directory LDAP endpoint as configured by [rgl/windows-domain-controller-vagrant](https://github.com/rgl/windows-domain-controller-vagrant).

[rgl/gitlab-source-link-proxy](https://github.com/rgl/gitlab-source-link-proxy) is installed to let you use [SourceLink](https://github.com/dotnet/sourcelink) to access the source code from within the Visual Studio debugger.

Some example repositories are automatically installed, if you do not want that, comment the line that calls [`create-example-repositories.sh`](create-example-repositories.sh) inside the [`provision.sh` file](provision.sh) before running `vagrant up`.

Email notifications are sent to a local [MailHog](https://github.com/mailhog/MailHog) SMTP server running at localhost:1025 and you can browse them at [http://gitlab.example.com:8025](http://gitlab.example.com:8025).

Prometheus is available at http://gitlab.example.com:9090/.

Grafana is available at https://gitlab.example.com/-/grafana.


# Usage

Start the environment:

    vagrant up

Configure your host system to resolve the `gitlab.example.com` domain to this vagrant environment IP address, e.g.:

```sh
echo '10.10.9.99 gitlab.example.com' | sudo tee -a /etc/hosts
```

Sign In into GitLab using the `root` username and the `password` password at:

> https://gitlab.example.com/users/sign_in

When using the default LDAP settings you can also login with LDAP credentials as the following users:

| Username      | Password        |
|---------------|-----------------|
| `john.doe`    | `HeyH0Password` |
| `jane.doe`    | `HeyH0Password` |

After login, you should add your [public SSH key](https://git-scm.com/book/en/v2/Git-on-the-Server-Generating-Your-SSH-Public-Key), for that open the SSH Keys page at:

> https://gitlab.example.com/profile/keys

Add a new SSH key with your SSH public key, for that, just copy the contents of
your `id_rsa.pub` file. Get its contents with, e.g.:

```sh
cat ~/.ssh/id_rsa.pub
```

Create a new repository named `hello` at:

> https://gitlab.example.com/projects/new

You can now clone that repository with SSH or HTTPS:

```sh
git clone git@gitlab.example.com:root/hello.git
git clone https://root@gitlab.example.com/root/hello.git
```

**NB** This vagrant environment does not have a proper SSL certificate, as such,
HTTPS cloning will fail with `SSL certificate problem: self signed certificate`.
To temporarily ignore that error set the [`GIT_SSL_NO_VERIFY` environment
variable](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables)
with `export GIT_SSL_NO_VERIFY=true`.

Make some changes to the cloned repository and push them:

```sh
cd hello
echo '# Hello World' >> README.md
git add README.md
git commit -m 'some change'
git push
```


# Git Large File Storage (LFS)

You can also use Git Large File Storage (LFS). As this is an external Git plugin,
you need to [install git-lfs](https://git-lfs.github.com/) before you continue.

**NB** `git-lfs` needs to be on your `PATH`. Normally the installer configures
your system `PATH`, but **you still need to restart your shell or Git Client
application** for it to pick it up.

Give it a try by cloning the example repository (created by
[create-example-repositories.sh](create-example-repositories.sh)):

```sh
git clone https://root:password@gitlab.example.com/example/use-git-lfs.git
```

**NB** `git-lfs` always uses an `https` endpoint (even when you clone with `ssh`).

Lets get familiar with `git-lfs` by running some commands.

See the available lfs commands:

```sh
git lfs
```

Which file patterns are currently being tracked:

```sh
git lfs track
```

**NB** do not forget, only the tracked files are put outside the git repository. So don't forget to
track. e.g., with `git lfs track "*.iso"`.

See which files are actually tracked:

```sh
git lfs ls-files
```

See the `git-lfs` environment:

```sh
git lfs env
```

For more information [read the tutorial](https://github.com/github/git-lfs/wiki/Tutorial)
and [the documentation](https://git-lfs.github.com/).


# Troubleshoot

Watch the logs:

```bash
sudo su -l
tail -f /var/log/gitlab/gitlab-rails/*.log
```

Do a self-check:

```bash
sudo gitlab-rake --trace gitlab:env:info
sudo gitlab-rake --trace gitlab:check SANITIZE=true
```


# Monitorization

By default Prometheus is configured to scrap the metric targets every 15 seconds and to store them for 15 days.

You can see the current targets at:

    http://gitlab.example.com:9090/targets

**WARNING** prometheus is configured to listen at `0.0.0.0`, you probably want to change this.

You can also see the Grafana dashboards at:

    https://gitlab.example.com/-/grafana


# Command Line Interface

GitLab has an [API](https://docs.gitlab.com/ce/api/README.html) which can be used from different applications, one of those, is the [`gitlab` cli application](https://python-gitlab.readthedocs.io/en/stable/cli.html), which is already installed in the vagrant environment (see [provision-gitlab-cli.sh](provision-gitlab-cli.sh)) and can be used as:

```bash
vagrant ssh
sudo su -l

# list all users.
gitlab -o yaml -f id,name,email user list --all

# list all groups and projects.
gitlab -o yaml -f id,visibility,full_path,web_url group list --all
gitlab -o yaml -f id,visibility,tag_list,path_with_namespace,web_url project list --all

# list all the projects protected branches, tags, members.
gitlab -o json -f id,visibility,tag_list,web_url project list --all >projects.json
jq '.[].id' projects.json | xargs -L1 gitlab project-protected-branch list --all --project-id
jq '.[].id' projects.json | xargs -L1 gitlab project-protected-tag list --all --project-id
jq '.[].id' projects.json | xargs -L1 gitlab project-member list --all --project-id
```

# Python Interface

[python-gitlab](https://github.com/python-gitlab/python-gitlab) is also available as the `gitlab` python library, which can be used as:

```python
import gitlab

gl = gitlab.Gitlab.from_config()

# list all users.
for user in gl.users.list(all=True):
    print(f'{user.id}\t{user.name}\t{user.email}')

# list all groups and projects.
for group in gl.groups.list(all=True):
    print(f'{group.id}\t{group.visibility}\t{group.full_path}\t{group.web_url}')
for project in gl.projects.list(all=True):
    print(f'{project.id}\t{project.visibility}\t{project.tag_list}\t{project.path_with_namespace}\t{project.web_url}')

# list project protected branches.
for project in gl.projects.list(all=True):
    has_i = False
    for i in project.protectedbranches.list(all=True):
        print(f'{project.web_url}\t{i.name}')
        has_i = True
    if not has_i:
        print(project.web_url)

# list project members.
# NB these members do not include the ones added to the group.
for project in gl.projects.list(all=True):
    has_member = False
    for member in project.members.list(all=True):
        # NB the member object does not contain the email attribute, so we also fetch the user.
        user = gl.users.get(id=member.id)
        print(f'{project.web_url}\t{user.username}\t{user.email}')
        has_member = True
    if not has_member:
        print(project.web_url)

# see more examples at https://python-gitlab.readthedocs.io/en/stable/api-objects.html
```

Also check the [set-example-groups-users.py](set-example-groups-users.py) script to see how you could add users to all groups.
