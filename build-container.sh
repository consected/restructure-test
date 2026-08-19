#!/bin/bash
# Setup the build container with
#    docker build . --no-cache -t consected/restructure-test

# set -xv
source /shared/default-ruby-version.sh
source /shared/build-vars.sh
source /shared/setup-dev-env.sh
source $HOME/.bash_profile
source /shared/lib/rbenv.sh

export HOME=/root

if [ -z "${RUBY_V}" ]; then
  echo "RUBY_V is not set in default-ruby-version.sh - ensure the DOCKERFILE copies it correctly"
  exit 5
fi

PGVER=18
NODEJS_VERSION=23

yum update -y
yum install -y deltarpm sudo rsync adduser procps
cd /root
chmod 600 /root/.netrc

yum update -y
yum install -y deltarpm sudo rsync adduser openssh-server
yum update

ssh-keygen -A

echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

/usr/sbin/sshd

curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
curl -fsSL https://rpm.nodesource.com/setup_${NODEJS_VERSION}.x -o nodesource_setup.sh && \
bash nodesource_setup.sh && \
yum install -y nodejs && node -v && \
yum install -y git yarn \
  openssl-devel readline-devel zlib-devel \
  gcc gcc-c++ make which mlocate \
  libffi libffi-devel libyaml libyaml-devel rsync sudo \
  tar bzip2 \
  words unzip

if [ $? != 0 ]; then
  echo 'Failed to install main packages'
  exit 7
fi

yum clean metadata

yum install -y postgresql${PGVER} postgresql${PGVER}-server libpq-devel postgresql${PGVER}-contrib

if [ -z "$(which psql)" ]; then
  echo "Failed to install psql"
  exit 8
fi

adduser postgres
ls /usr/
ls /usr/bin/
# Setup Postgres
sudo -u postgres initdb /var/lib/pgsql/data
sudo -u postgres pg_ctl start -D /var/lib/pgsql/data -s -o "-p 5432" -w -t 300
psql --version
sudo -u postgres psql -c 'SELECT version();' 2>&1

# For UI features testing
source /shared/setup_restructure_eb.sh
setup_restructure_eb
wget -O geckodriver.tar.gz ${GECKODRIVER}
tar -xvf geckodriver.tar.gz
mv geckodriver /usr/local/bin/
chmod 777 /usr/local/bin/geckodriver

install_rbenv
ensure_ruby_version "${RUBY_V}"
gem install bundler
