#!/bin/bash
set -euxo pipefail

# create some example users.
bash /vagrant/create-example-users.sh

# create some example repositories.
bash /vagrant/create-example-repositories.sh

# configure the jenkins-to-gitlab integration.
bash /vagrant/create-example-jenkins-to-gitlab-configuration.sh
