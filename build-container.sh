#!/bin/bash
# Setup the build container with
#    docker build . --no-cache -t consected/restructure-test

ls -als /shared
source /shared/build-vars.sh
source /shared/setup-dev-env.sh
source $HOME/.bash_profile

echo "**** Building consected/restructure-test container ****"

if [ -z ${PGSQL_DATA_DIR} ]; then
  echo 'PGSQL_DATA_DIR not set. Probably failed to load setup-dev-env.sh'
  exit 9
fi

cd /root
chmod 600 /root/.netrc

if [ ${DEBUG_BUILD} ]; then
  echo "Debug build - exiting"
  exit
fi

yum update -y
yum install -y deltarpm sudo rsync adduser openssh-server
yum update

ssh-keygen -A

echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

/usr/sbin/sshd

curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
yum install https://rpm.nodesource.com/pub_16.x/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm -y
yum install nodejs -y --setopt=nodesource-nodejs.module_hotfixes=1

amazon-linux-extras

yum install -y git yarn \
  llvm-toolset-7-clang \
  openssl-devel readline-devel zlib-devel \
  gcc gcc-c++ make which mlocate \
  tar bzip2 \
  words procps-ng \
  unzip libyaml libyaml-devel

if [ $? != 0 ]; then
  echo 'Failed to install main packages'
  exit 7
fi

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
