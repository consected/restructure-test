#!/bin/bash
# Setup the build container with
#    docker build . --no-cache -t consected/restructure-test

# set -xv
source /shared/build-vars.sh
export HOME=/root

PGVER=12

yum update -y
yum install -y deltarpm sudo rsync adduser
yum update

curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
curl --silent --location https://rpm.nodesource.com/setup_14.x | bash -

amazon-linux-extras

yum install -y git yarn \
  llvm-toolset-7-clang \
  openssl-devel readline-devel zlib-devel \
  gcc gcc-c++ make which mlocate \
  tar bzip2 \
  words procps-ng

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
amazon-linux-extras install -y epel
yum install -y bindfs autoconf fuse fuse-libs fuse-devel libarchive libarchive-devel x11vnc Xvfb unzip zip wget
modprobe fuse
amazon-linux-extras install -y firefox
amazon-linux-extras install -y libreoffice
amazon-linux-extras install -y R4
yum install -y dcmtk poppler-cpp poppler-cpp-devel netpbm netpbm-progs

pip3 install ocrmypdf
yum-config-manager --add-repo https://download.opensuse.org/repositories/home:/Alexander_Pozdnyakov/CentOS_7/
rpm --import https://build.opensuse.org/projects/home:Alexander_Pozdnyakov/public_key
yum update
yum install -y tesseract
yum install -y tesseract-langpack-deu

wget -O geckodriver.tar.gz ${GECKODRIVER}
tar -xvf geckodriver.tar.gz
mv geckodriver /usr/local/bin/
chmod 777 /usr/local/bin/geckodriver

# Alternative to x11vnc and Xvfb
# amazon-linux-extras install -y mate-desktop1.x firefox
# bash -c 'echo PREFERRED=/usr/bin/mate-session > /etc/sysconfig/desktop'

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
