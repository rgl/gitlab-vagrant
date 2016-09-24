# Environment

This [vagrant](https://www.vagrantup.com/) environment configures a basic [GitLab Community Edition](https://gitlab.com/gitlab-org/gitlab-ce) installation using the [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab) package.

[Nginx](http://nginx.org/en/) ([HTTP/2](https://en.wikipedia.org/wiki/HTTP/2) enabled) is configured with a self-signed certificate at:

> https://gitlab.example.com/

[PostgreSQL](http://www.postgresql.org/) is configured to allow (and trust) any connection from the host. For example, you can use [pgAdmin III](http://www.pgadmin.org/) with these settings:

    Host: gitlab.example.com
    Port: 5432
    Maintenance DB: postgres
    Username: gitlab-psql

GitLab is configured to access the `ldaps://dc.example.com` Active Directory LDAP endpoint (for this to work, [rgl/windows-domain-controller-vagrant](https://github.com/rgl/windows-domain-controller-vagrant]) must be up and running).

Some example repositories are automatically installed, if you do not want that, comment the line that calls [`create-example-repositories.sh`](create-example-repositories.sh) inside the [`provision.sh` file](provision.sh) before running `vagrant up`.


# Usage

Start the environment:

    vagrant up 

Configure your host system to resolve the `gitlab.example.com` domain to this vagrant environment IP address, e.g.:

```sh
echo '192.168.33.20 gitlab.example.com' | sudo tee -a /etc/hosts
```

Sign In into GitLab using the `root` username and the `password` password at:

> https://gitlab.example.com/users/sign_in

Add your [public SSH key](https://git-scm.com/book/en/v2/Git-on-the-Server-Generating-Your-SSH-Public-Key), for that open the SSH Keys page at:

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
git clone https://root:password@gitlab.example.com/root/use-git-lfs.git
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
sudo su
tail -f /var/log/gitlab/gitlab-rails/*.log
```
