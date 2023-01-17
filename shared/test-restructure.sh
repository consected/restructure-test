#!/bin/bash

source /shared/build-vars.sh

PGSQLBIN=/usr/bin
export PATH=${PGSQLBIN}:$PATH
export PGCLIENTENCODING=UTF8
export HOME=/root
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
export NO_BRAKEMAN
export FS_TEST_BASE=/root
export FS_FORCE_ROOT=true
export WEBAPP_USER=$(whoami)
export NOT_HEADLESS=false

source $HOME/.bash_profile
BUILD_DIR=/output/restructure
DOCS_BUILD_DIR=${BUILD_DIR}-docs

cp /shared/.netrc ${HOME}/.netrc
chmod 600 ${HOME}/.netrc

echo > /shared/build_version.txt

function check_version_and_exit() {
  IFS='.' read -a OLD_VER_ARRAY < version.txt
  if [ -z "${OLD_VER_ARRAY[0]}" ] || [ -z "${OLD_VER_ARRAY[1]}" ] || [ -z "${OLD_VER_ARRAY[2]}" ]; then
    echo "Current version is incorrect format: $(cat version.txt)"
    echo "This can often be resolved simply by re-running the build script."
    exit 1
  fi
}

# Setup App environment
if [ "${DB_NAME}" ]; then
  export FPHS_POSTGRESQL_DATABASE=${DB_NAME}
fi
export FPHS_POSTGRESQL_USERNAME=${DB_USER}
export FPHS_POSTGRESQL_PASSWORD=${DB_PASSWORD}
export FPHS_POSTGRESQL_PORT=5432
export FPHS_POSTGRESQL_HOSTNAME=localhost
# export FPHS_RAILS_DEVISE_SECRET_KEY="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 1)"
# export FPHS_RAILS_SECRET_KEY_BASE="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 1)"
export RAILS_ENV=test

# Check rsync is installed
if [ ! "$(which rsync)" ]; then
  yum install -y rsync
fi

# Start DB
if [ ! -d /var/lib/pgsql/data ]; then
  echo "Initializing the database"
  sudo -u postgres ${PGSQLBIN}/initdb /var/lib/pgsql/data
fi

echo "Starting the database"
sudo -u postgres ${PGSQLBIN}/pg_ctl start -D /var/lib/pgsql/data -s -o "-p 5432" -w -t 300
sudo -u postgres psql -c 'SELECT version();'

# Get source

if [ ! -f ${BUILD_DIR}/.git/HEAD ]; then
  echo "Cloning repo"
  rm -rf ${BUILD_DIR}
  rm -rf ${DOCS_BUILD_DIR}
  cd $(dirname ${BUILD_DIR})
  git clone ${REPO_URL} ${BUILD_DIR}
  git clone ${DOCS_REPO_URL} ${DOCS_BUILD_DIR}
  FIRST_RUN=true
else
  echo "Pulling from repo"
fi

if [ ! -f ${BUILD_DIR}/.git/HEAD ]; then
  echo "Failed to get the build repo"
  exit 1
fi

cd ${BUILD_DIR}
rbenv local ${RUBY_V}
rbenv global ${RUBY_V}

if [ "$(cat ${BUILD_DIR}/.ruby-version)" != ${RUBY_V} ]; then
  rbenv install ${RUBY_V}
  rbenv local ${RUBY_V}
  rbenv global ${RUBY_V}
fi

if [ "$(cat ${BUILD_DIR}/.ruby-version)" != ${RUBY_V} ]; then
  echo "Ruby versions don't match: $(cat ${BUILD_DIR}/.ruby-version) != ${RUBY_V}"
  exit 7
fi

if [ ! -f ${DOCS_BUILD_DIR}/.git/HEAD ]; then
  echo "Failed to get the docs repo"
  exit 8
fi

cd ${BUILD_DIR}
git config --global user.email ${GIT_EMAIL}
git config --global user.name "Restructure TEST Process"
git config --global push.default matching
git config --global http.postBuffer 500M
git config --global http.maxRequestBuffer 100M
git config --global https.postBuffer 500M
git config --global https.maxRequestBuffer 100M
git config --global core.compression 0

# Checkout branch to build
pwd
# Setting up a new repo breaks if .ruby-version is there before the repo
git stash save .ruby-version
git checkout ${TEST_GIT_BRANCH} || git checkout -b ${TEST_GIT_BRANCH} --track origin/${TEST_GIT_BRANCH}
git pull
mkdir -p tmp
chmod 774 tmp
mkdir -p log
chmod 774 log
touch log/delayed_job.log
chmod 664 log/delayed_job.log

if [ ! -f Gemfile ]; then
  echo "No Gemfile found after checking out branch ${TEST_GIT_BRANCH} to $(pwd)"
  exit 1
fi

if [ ! -f .ruby-version ]; then
  echo "No .ruby-version found after checking out branch ${TEST_GIT_BRANCH} to $(pwd)"
  exit 1
fi

check_version_and_exit

cd ${BUILD_DIR}

echo "Creating Filestore"
app-scripts/setup-init-mounts.sh
if [ $? != 0 ]; then
  echo "Failed to initialize mounts"
  exit 9
fi
RAILS_ENV= app-scripts/setup-dev-filestore.sh
if [ $? != 0 ]; then
  echo "Failed to setup dev filestore"
  exit 9
fi
SUBDIR=test-fphsfs app-scripts/setup_filestore_app.sh 1
if [ $? != 0 ]; then
  echo "Failed to setup filestore app 1"
  exit 9
fi

# echo "Cleanup db dir"
rm -f db/app_configs
rm -f db/app_migrations
rm -f db/app_specific

echo "Handle rbenv"

if [ "$(rbenv local)" != "${RUBY_V}" ] || [ -z "$(ruby --version | grep ${RUBY_V})" ]; then
  echo "Installing new ruby version ${RUBY_V}"
  git -C /root/.rbenv/plugins/ruby-build pull
  rbenv install ${RUBY_V}
  rbenv local ${RUBY_V}
  rbenv global ${RUBY_V}
fi

if [ "$(rbenv local)" != "${RUBY_V}" ]; then
  echo "Failed to install or use ruby version ${RUBY_V}. rbenv is using $(rbenv local). The file .ruby-version is #(cat .ruby-version)"
  exit 70
fi

rbenv local ${RUBY_V}
rbenv global ${RUBY_V}
echo "Using ruby version $(rbenv local)"
which ruby
ruby --version

echo "Bundle"
rm -f .bundle/config
gem install bundler

bundle install

bundle check
if [ "$?" != "0" ]; then
  echo "bundle check failed"
  exit 7
fi

bin/yarn install --frozen-lockfile

if [ ! -d node_modules ]; then
  echo "No node_modules after yarn install"
  exit 1
fi

# Setup add DB

if [ "$(grep '<<<< HEAD' db/structure)" ]; then
  echo 'Merge failures are in the db structure'
  exit 65
fi

echo "localhost:5432:*:${DB_USER}:${DB_PASSWORD}" > ${HOME}/.pgpass
chmod 600 /root/.pgpass

psql --version

echo "Create user ${DB_USER}"
sudo -u postgres ${PGSQLBIN}/psql 2>&1 << EOF
SELECT version();
CREATE USER ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
EOF

if [ "${DROP_DATABASE}" == 'true' ]; then
  echo "Dropping database"
  app-scripts/drop-test-db.sh
fi

echo "Creating database"
DBOWNER=${DB_USER} app-scripts/create-test-db.sh

echo "Run tests"
app-scripts/parallel_test.sh ${RUN_SPECS}

chmod o+rx tmp
chmod o+r tmp/failing_specs.log
if [ "$?" == 0 ]; then
  echo "rspec OK"
  echo "View test log: less -r output/restructure/tmp/failing_specs.log"
else
  echo "View test log: less -r output/restructure/tmp/failing_specs.log"
  echo "rspec Failed"
  exit 1
fi
