#!/bin/bash
# Setup the build container with
#    docker build . --no-cache -t consected/restructure-build

# set -xv
source /shared/default-ruby-version.sh
source /shared/build-vars.sh
source /shared/setup-dev-env.sh
source $HOME/.bash_profile

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


# Install rbenv
git clone https://github.com/rbenv/rbenv.git ${HOME}/.rbenv
${HOME}/.rbenv/bin/rbenv init
echo 'eval "$(rbenv init -)"' >> ${HOME}/.bash_profile
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init -)"
. /root/.bash_profile
#curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-doctor | bash
mkdir -p "$(rbenv root)"/plugins
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
rbenv install --list
rbenv install --skip-existing ${RUBY_V}
rbenv rehash

# Install ruby, etc
if [ "$(rbenv local)" != "${RUBY_V}" ]; then
  echo "Installing new ruby version ${RUBY_V}"
  git -C /root/.rbenv/plugins/ruby-build pull && \
  rbenv install --skip-existing ${RUBY_V} && \
  rbenv global ${RUBY_V} && \
  rbenv local ${RUBY_V} && \
  gem install bundler
  if [ $? != 0 ] || [ "$(rbenv local)" != "${RUBY_V}" ]; then
    echo "Failed to install new ruby version ${RUBY_V} and bundler gem"
    rbenv local
    exit 18
  fi
fi
