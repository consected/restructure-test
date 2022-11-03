#!/bin/bash
# Setup the build container with
#    docker build . --no-cache -t consected/restructure-build

# set -xv
source /shared/build-vars.sh
export HOME=/root

PGVER=12

yum update -y
yum install -y deltarpm sudo rsync adduser
yum update

curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
curl --silent --location https://rpm.nodesource.com/setup_12.x | bash -

amazon-linux-extras

# yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-latest-x86_64/postgresql10-libs-10.10-1PGDG.rhel7.x86_64.rpm
# yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-latest-x86_64/postgresql10-10.10-1PGDG.rhel7.x86_64.rpm
# yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-latest-x86_64/postgresql10-server-10.10-1PGDG.rhel7.x86_64.rpm
# yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-latest-x86_64/postgresql10-devel-10.10-1PGDG.rhel7.x86_64.rpm
# yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-latest-x86_64/postgresql10-contrib-10.10-1PGDG.rhel7.x86_64.rpm

# yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

yum install -y git yarn \
  llvm-toolset-7-clang \
  openssl-devel readline-devel zlib-devel \
  gcc gcc-c++ make which mlocate \
  tar bzip2 \
  words

amazon-linux-extras enable postgresql${PGVER} vim epel
yum clean metadata

yum install -y postgresql postgresql-server postgresql-devel postgresql-contrib

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
# yum install -y firefox Xvfb x11vnc

# Install rbenv
git clone https://github.com/rbenv/rbenv.git ${HOME}/.rbenv
cd ${HOME}/.rbenv && src/configure && make -C src
echo 'eval "$(rbenv init -)"' >> ${HOME}/.bash_profile
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init -)"
. /root/.bash_profile
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-doctor | bash
mkdir -p "$(rbenv root)"/plugins
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
rbenv install --list
rbenv rehash

# Install ruby, etc
if [ "$(rbenv local)" != "${RUBY_V}" ]; then
  rbenv install ${RUBY_V}
  rbenv global ${RUBY_V}
  gem install bundler
fi
