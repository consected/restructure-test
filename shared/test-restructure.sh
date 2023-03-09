#!/bin/bash

source /shared/build-vars.sh
source /shared/setup-dev-env.sh
source $HOME/.bash_profile

echo "**** Running test-restructure - $@ ****"

function stop_db() {
  sudo -u postgres ${PGSQLBIN}/pg_ctl status -D ${PGSQL_DATA_DIR} -o "-p ${PGPORT}"
  if [ $? == 0 ]; then
    echo 'Stopping the database'
    sudo -u postgres ${PGSQLBIN}/pg_ctl stop -D ${PGSQL_DATA_DIR} -o "-p ${PGPORT}" -w -t 300
    echo "Stop code: $?"
    sleep 5
  fi
}

function start_db() {
  sudo -u postgres ${PGSQLBIN}/pg_ctl status -D ${PGSQL_DATA_DIR}
  if [ $? != 0 ]; then
    echo 'pg_ctl says the DB is already running, which cause a failure in a moment'
  fi

  echo 'Starting the DB'
  sudo -u postgres ${PGSQLBIN}/pg_ctl start -D ${PGSQL_DATA_DIR} -o "-p ${PGPORT}" -w -t 300
}

NO_TEST=true

if [ "$1" == 'setup-dev' ]; then
  echo "**** Setting up development environment ****"
  SETUP_DEV=true
fi

if [ "$1" == 'test' ]; then
  echo "**** Setting up test environment ****"
  unset NO_TEST
fi

if [ "$2" == 'clean-output' ]; then
  echo "**** Cleaning output and database ****"
  stop_db
  echo 'Removing files as /output'
  rm -rf /output/*
fi

chmod 777 /tmp

BUILD_DIR=/output/restructure
DOCS_BUILD_DIR=${BUILD_DIR}-docs

mkdir -p /output
chmod 600 ${HOME}/.netrc

function check_version_and_exit() {
  IFS='.' read -a OLD_VER_ARRAY < version.txt
  if [ -z "${OLD_VER_ARRAY[0]}" ] || [ -z "${OLD_VER_ARRAY[1]}" ] || [ -z "${OLD_VER_ARRAY[2]}" ]; then
    echo "Current version is incorrect format: $(cat version.txt)"
    echo "This can often be resolved simply by re-running the build script."
    exit 1
  fi
}

# Start DB
if [ ! -d ${PGSQL_DATA_DIR} ]; then
  echo "Initializing the database"

  # Setup Postgres
  mkdir -p ${PGSQL_DATA_DIR}
  chown postgres:postgres ${PGSQL_DATA_DIR}

  sudo -u postgres ${PGSQLBIN}/initdb ${PGSQL_DATA_DIR}
  if [ $? != 0 ]; then
    echo 'Failed to install database'
    exit 9
  fi
  ls ${PGSQL_DATA_DIR}
  sleep 5

  start_db
  if [ $? != 0 ]; then
    echo 'Failed to start database'
    echo 'Other postgres processes:'
    ps aux | grep 'postgres'
    exit 9
  fi
  psql --version
  sudo -u postgres psql -c 'SELECT version();' 2>&1

  echo "localhost:${PGPORT}:*:${DB_USER}:${DB_PASSWORD}" > ${HOME}/.pgpass
  chmod 600 /root/.pgpass

  psql --version

  echo "Create user ${DB_USER}"
  sudo -u postgres ${PGSQLBIN}/psql 2>&1 << EOF
SELECT version();
CREATE USER ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
EOF

else
  echo "Starting the database"
  ps aux | grep 'postgres'

  stop_db
  start_db

  if [ $? != 0 ]; then
    echo 'Failed to start database'
    echo 'Other postgres processes:'
    ps aux | grep 'postgres'
    exit 9
  fi
  ps aux | grep 'postgres'
  sudo -u postgres psql -c 'SELECT version();'
fi

# Get source

cd $(dirname ${BUILD_DIR})
git config --global user.email ${GIT_EMAIL}
git config --global user.name "Restructure TEST Process"
git config --global push.default matching
git config --global http.postBuffer 500M
git config --global http.maxRequestBuffer 100M
git config --global https.postBuffer 500M
git config --global https.maxRequestBuffer 100M
git config --global core.compression 0

if [ ! -f ${BUILD_DIR}/.git/HEAD ]; then
  echo "Cloning repo"
  rm -rf ${BUILD_DIR}
  cd $(dirname ${BUILD_DIR})
  git clone ${REPO_URL} ${BUILD_DIR}
  git stash save .ruby-version
  git checkout ${TEST_GIT_BRANCH} || git checkout -b ${TEST_GIT_BRANCH} --track origin/${TEST_GIT_BRANCH}

  if [ ! -f ${BUILD_DIR}/.git/HEAD ]; then
    echo "Failed to get the build repo"
    exit 1
  fi
  PULL_REPO=true
else
  echo "Will pull from repo"
  git pull
fi

if [ "${SETUP_DEV}" ] || [ "${PULL_REPO}" ]; then
  echo 'Pull source repo'
  cd ${BUILD_DIR}

  # Ensure we don't get an unnecessary conflict if .ruby-version is there before the repo
  git stash save .ruby-version
  git checkout ${TEST_GIT_BRANCH} || git checkout -b ${TEST_GIT_BRANCH} --track origin/${TEST_GIT_BRANCH}
  git pull
  mkdir -p tmp
  chmod 774 tmp
  mkdir -p log
  chmod 774 log
  touch log/delayed_job.log
  chmod 664 log/delayed_job.log
fi

cd ${BUILD_DIR}
if [ ! -f Gemfile ]; then
  echo "No Gemfile found after checking out branch ${TEST_GIT_BRANCH} to $(pwd)"
  ls
  exit 1
fi

if [ ! -f .ruby-version ]; then
  echo "No .ruby-version found after checking out branch ${TEST_GIT_BRANCH} to $(pwd)"
  exit 1
fi

if [ ! -f ${DOCS_BUILD_DIR}/.git/HEAD ]; then
  cd $(dirname ${DOCS_BUILD_DIR})
  echo "Cloning docs repo"
  rm -rf ${DOCS_BUILD_DIR}
  cd $(dirname ${DOCS_BUILD_DIR})
  git clone ${DOCS_REPO_URL} ${DOCS_BUILD_DIR}
  if [ ! -f ${DOCS_BUILD_DIR}/.git/HEAD ]; then
    echo "Failed to get the docs repo"
    exit 8
  fi
else
  echo "Pulling from docs repo"
  cd ${DOCS_BUILD_DIR}
  git pull
fi

cd ${BUILD_DIR}

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

if [ "${NO_TEST}" ]; then
  if [ "${APPS_REPO_URL}" ]; then
    echo "Set up apps repo"
    cd ..
    git clone ${APPS_REPO_URL}
    cd -
    git checkout db/app_configs
    git checkout db/app_migrations
    git checkout db/app_specific
  fi
else
  echo "Cleanup db dir"
  rm -f db/app_configs
  rm -f db/app_migrations
  rm -f db/app_specific
fi

echo "Handle rbenv"
SOURCE_RUBY_V=$(cat ${BUILD_DIR}/.ruby-version)
RBENV_LOCAL=$(rbenv local)
if [ "${SOURCE_RUBY_V}" != ${RUBY_V} ] || [ "${RBENV_LOCAL}" != "${RUBY_V}" ]; then
  echo "Ruby versions don't match: ${SOURCE_RUBY_V} !=? ${RUBY_V} !=? ${RBENV_LOCAL}"
  echo "Change the build-vars.sh specification and rebuild the container"
  exit 7
fi

echo "Bundle"
rm -f .bundle/config
gem install bundler

# Install gems with versions specified in the lockfile
bundle install

bundle check
if [ "$?" != "0" ]; then
  echo "bundle check failed"
  exit 7
fi

# Install JS modules with the versions specified in the lockfile
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

if [ "${DROP_DATABASE}" == 'true' ]; then
  echo "Dropping database"
  app-scripts/drop-test-db.sh
fi

if [ "${SETUP_DEV}" ]; then
  echo "Creating database for dev"
  unset RAILS_ENV
  sudo -u postgres psql -c "create database ${DEV_DB_NAME} owner ${DB_USER};"
  psql -d ${DEV_DB_NAME} < db/structure.sql
  bundle exec rake db:migrate

  if [ -f db/demo-data.zip ]; then
    rm -f db/demo-data.sql
    unzip db/demo-data.zip -d db/
    psql -d ${DEV_DB_NAME} < db/demo-data.sql
    rm -f db/demo-data.sql
  fi

  bundle exec rake db:seed

  # Discard any changes to the structure that have been introduced
  git checkout db/structure.sql

  /shared/run-dev.sh
fi

if [ -z ${NO_TEST} ]; then
  export RAILS_ENV=test

  echo "Creating database for test"
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
fi

echo 'Exiting test-restructure.sh'
