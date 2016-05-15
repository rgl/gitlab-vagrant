# Environment

This [vagrant](https://www.vagrantup.com/) environment configures a basic [GitLab Community Edition](https://gitlab.com/gitlab-org/gitlab-ce) installation using the [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab) package.

[Nginx](http://nginx.org/en/) ([HTTP/2](https://en.wikipedia.org/wiki/HTTP/2) enabled) is configured with a self-signed certificate at:

> https://gitlab.example.com/

[PostgreSQL](http://www.postgresql.org/) is configured to allow (and trust) any connection from the host. For example, you can use [pgAdmin III](http://www.pgadmin.org/) with these settings:

    Host: gitlab.example.com
    Port: 5432
    Maintenance DB: postgres
    Username: gitlab-psql

Some example repositories are automatically installed, if you do not want that, comment the line that calls [`import-repositories.sh`](import-repositories.sh) inside the [`provision.sh` file](provision.sh) before running `vagrant up`.


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
GIT_SSL_NO_VERIFY=true git clone https://root@gitlab.example.com/root/hello.git
```

**NB** This vagrant environment does not have a proper SSL certificate, as such,
HTTPS cloning will fail with `SSL certificate problem: self signed certificate`.
To temporarily ignore that error we set the [`GIT_SSL_NO_VERIFY=true` environment
variable](https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables).

Make some changes to the cloned repository and push them:

```sh
cd hello
echo '# Hello World' >> README.md
git add README.md
git commit -m 'some change'
GIT_SSL_NO_VERIFY=true git push
```
