#!/bin/bash

source /shared/build-vars.sh

PGSQLBIN=/usr/bin
export PATH=${PGSQLBIN}:$PATH
export PGCLIENTENCODING=UTF8
export HOME=/root
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
source $HOME/.bash_profile
BUILD_DIR=/output/restructure
DOCS_BUILD_DIR=${BUILD_DIR}-docs
DEV_COPY=${BUILD_DIR}-dev

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
export FPHS_POSTGRESQL_DATABASE=${DB_NAME}
export FPHS_POSTGRESQL_USERNAME=${DB_USER}
export FPHS_POSTGRESQL_PASSWORD=${DB_PASSWORD}
export FPHS_POSTGRESQL_SCHEMA=${APP_DB_SEARCH_PATH}
export FPHS_POSTGRESQL_PORT=5432
export FPHS_POSTGRESQL_HOSTNAME=localhost
export FPHS_RAILS_DEVISE_SECRET_KEY="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 1)"
export FPHS_RAILS_SECRET_KEY_BASE="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 128 | head -n 1)"
export RAILS_ENV=production

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
rm -rf ${BUILD_DIR}
rm -rf ${DOCS_BUILD_DIR}
rm -rf ${DEV_COPY}
echo "Cloning repo"
cd $(dirname ${BUILD_DIR})
git clone ${REPO_URL} ${BUILD_DIR}
git clone ${DOCS_REPO_URL} ${DOCS_BUILD_DIR}

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

git stash save

if [ ! -f ${DOCS_BUILD_DIR}/.git/HEAD ]; then
  echo "Failed to get the docs repo"
  exit 8
fi

cd ${BUILD_DIR}
git config --global user.email ${GIT_EMAIL}
git config --global user.name "Restructure Build Process"
git config --global push.default matching
git config --global http.postBuffer 500M
git config --global http.maxRequestBuffer 100M
git config --global https.postBuffer 500M
git config --global https.maxRequestBuffer 100M
git config --global core.compression 0

# Checkout branch to build
pwd
git checkout ${BUILD_GIT_BRANCH} || git checkout -b ${BUILD_GIT_BRANCH} --track origin/${BUILD_GIT_BRANCH}
git pull
mkdir -p tmp
chmod 774 tmp
mkdir -p log
chmod 774 log
touch log/delayed_job.log
chmod 664 log/delayed_job.log

if [ ! -f Gemfile ]; then
  echo "No Gemfile found after checking out branch ${BUILD_GIT_BRANCH} to $(pwd)"
  exit 1
fi

if [ "${ONLY_PUSH_TO_PROD_REPO}" != 'true' ]; then
  echo "Creating a copy of the prod repo for development"
  mkdir -p ${DEV_COPY}
  rsync -a --delete ${BUILD_DIR}/ ${DEV_COPY}/
fi

check_version_and_exit

echo "Setup remote repos"
if [ "${PROD_REPO_URL}" ]; then
  git remote set-url --add origin ${PROD_REPO_URL}
  git remote set-url --push --add origin ${PROD_REPO_URL}
  git remote set-url --delete origin ${REPO_URL}
  git pull
  git merge origin/${BUILD_GIT_BRANCH} -m "Merge remote" &&
    git commit -a -m "Commit"
  git push -f

  if [ $? != 0 ]; then
    echo "Failed to push to remotes. Will not continue."
    exit 45
  fi

fi

cd ${BUILD_DIR}

echo "Sync app reference"
# Remove the link to the docs repo then copy the full structure into the build repo
# so that it is versioned and can be deployed
rm -rf docs/app_reference
mkdir -p docs/app_reference
rsync -av --delete ${DOCS_BUILD_DIR}/app_reference docs
git add docs

echo "Add db"
rm -f db/app_configs
rm -f db/app_migrations
rm -f db/app_specific

git add db

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
git --version
git --help

bundle remove e2mmap
bundle remove solargraph

bundle install --system --no-deployment
bundle package --all
bundle cache --all

if [ ! -d vendor/cache ]; then
  echo "No vendor/cache after bundle package"
  exit 1
fi

bundle check
if [ "$?" != "0" ]; then
  echo "bundle check failed"
  exit 7
fi

git add vendor/cache
git add Gemfile*
git add .ruby-version

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

echo "Create user ${DB_USER} and drop schema in DB ${DB_NAME}"
sudo -u postgres ${PGSQLBIN}/psql 2>&1 << EOF
SELECT version();

CREATE USER ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOF

echo "Load structure"
psql -d ${DB_NAME} -U ${DB_USER} -h localhost < db/structure.sql > /dev/null

echo "Grant privileges, setup pgcrypto and replace migration list"
sudo -u postgres ${PGSQLBIN}/psql ${DB_NAME} 2>&1 << EOF
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${DB_DEFAULT_SCHEMA} TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ${DB_DEFAULT_SCHEMA} TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA ${DB_DEFAULT_SCHEMA} TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA ${DB_DEFAULT_SCHEMA} TO ${DB_USER};

CREATE EXTENSION if not exists pgcrypto;
EOF

echo "Upversion code"
rm -f app-scripts/.ruby_version
TARGET_VERSION=$(ruby app-scripts/upversion.rb)

if [ -z "${TARGET_VERSION}" ]; then
  echo "TARGET_VERSION not set"
  exit 1
fi

check_version_and_exit
echo "Target version ${TARGET_VERSION}"

echo "Update CHANGELOG"
CL_TITLE="## [${TARGET_VERSION}] - $(date +%Y-%m-%d)"
sed -i -E "s/## Unreleased/${CL_TITLE}/" CHANGELOG.md

git add version.txt CHANGELOG.md

echo "Commit the new version"
git commit version.txt CHANGELOG.md -m "new version created $(cat version.txt)"

echo "Cleanup assets"
rm -rf public/assets
bundle exec rake assets:clobber
bundle exec rake assets:precompile --trace

if [ "$?" != 0 ] || [ ! -d public/assets ]; then
  echo "Failed to precompile assets"
  exit 3
fi

# Special case to allow third-party CSS in modules to reference images without requiring changes
# to account for Rails compiling assets with random filenames.
cp vendor/assets/images/* public/assets/

git add public/assets

echo "Run static analysis tests"
bundle exec brakeman -o security/brakeman-output-${TARGET_VERSION}.md
if [ "$?" == 0 ]; then
  echo "Brakeman OK"
else
  echo "Brakeman Failed"
  exit 1
fi
bundle exec bundle-audit update 2>&1 > security/bundle-audit-update-${TARGET_VERSION}.md
bundle exec bundle-audit check 2>&1 > security/bundle-audit-output-${TARGET_VERSION}.md
RES=$?
if [ "${RES}" == 0 ]; then
  echo "bundle-audit OK"
else
  echo "bundle-audit Failed: ${RES}"
  cat security/bundle-audit-output-${TARGET_VERSION}.md
  exit 1
fi

echo "Prep new DB dump"
rm -f db/dumps/current_schema.sql
echo "begin;" > /tmp/current_schema.sql

DUMP_SCHEMAS_ARGS=''
for s in ${DUMP_SCHEMAS}; do
  DUMP_SCHEMAS_ARGS="${DUMP_SCHEMAS_ARGS} -n ${s} "
done

pg_dump -O ${DUMP_SCHEMAS_ARGS} -d ${DB_NAME} -s -x >> /tmp/current_schema.sql
echo "commit;" >> /tmp/current_schema.sql
mv /tmp/current_schema.sql db/dumps/
bundle exec rake db:structure:dump

sudo -u postgres ${PGSQLBIN}/psql ${DB_NAME} << EOF
drop database if exists ${TEST_DB_NAME};
EOF

if [ "${RUN_TESTS}" == 'true' ]; then
  echo "Run tests"

  app-scripts/create-test-db.sh
  FPHS_ADMIN_SETUP=yes RAILS_ENV=test bundle exec rake db:seed
  IGNORE_MFA=true RAILS_ENV=test bundle exec rspec ${RSPEC_OPTIONS}
  if [ "$?" == 0 ]; then
    echo "rspec OK"
  else
    echo "rspec Failed"
    exit 1
  fi
fi

# Commit the new assets and schema
echo "Pull from: $(git config --get remote.origin.url)"
git pull

echo "Add final changes, commit and tag"
git add -A
git commit -m "Built and tested release-ready version '${TARGET_VERSION}'"
git tag -a "${TARGET_VERSION}" -m "Push release"

echo "Push to: $(git config --get remote.origin.url)"
git push
git push origin ${TARGET_VERSION}
git push origin --all

# git push -f origin "${TARGET_VERSION}"

# If we are pushing to both prod and dev repos
if [ "${ONLY_PUSH_TO_PROD_REPO}" != 'true' ]; then

  echo "Copy files to dev directory for separate git push"

  mkdir -p ${DEV_COPY}/security
  mkdir -p ${DEV_COPY}/db/dumps

  for f in \
    version.txt CHANGELOG.md \
    security/brakeman-output-${TARGET_VERSION}.md \
    security/bundle-audit-update-${TARGET_VERSION}.md \
    security/bundle-audit-output-${TARGET_VERSION}.md \
    db/dumps/current_schema.sql db/structure.sql; do

    cp -f ${f} ${DEV_COPY}/${f}

  done

  echo "Switching to dev copy ${DEV_COPY}"
  cd ${DEV_COPY}

  rm -rf public/assets
  rm -rf node_modules
  rm -rf vendor/cache/*

  if [ "${ONLY_PUSH_ASSETS_TO_PROD_REPO}" != 'true' ]; then
    # Cleanup the built assets
    echo "Also pushing assets to dev repo."
    for f in public/assets node_modules vendor/cache/; do
      mkdir -p ${DEV_COPY}/${f}
      rsync -av ${BUILD_DIR}/${f}/ ${DEV_COPY}/${f}/
    done
  fi

  echo "Handling git asset, db and security updates"
  pwd
  git init
  git add -A
  git status

  # Reset the remote urls for the dev repo
  echo "Pushing changes back to dev repo"

  git remote set-url --add origin ${REPO_URL}
  git remote set-url --push --add origin ${REPO_URL}
  git remote set-url --delete origin ${PROD_REPO_URL}
  git remote set-url --delete --push origin ${PROD_REPO_URL}

  echo "Remote set to: $(git config --get remote.origin.url)"
  echo "Final pull from dev repo"
  git fetch origin ${BUILD_GIT_BRANCH}
  git pull
  git add -A
  git commit -m "Built and tested release-ready version '${TARGET_VERSION}' - dev repo"
  git tag -a "${TARGET_VERSION}" -m "Push release"

  echo "Dev repo config"
  git config --global http.postBuffer 500M
  git config --global http.maxRequestBuffer 100M
  git config --global https.postBuffer 500M
  git config --global https.maxRequestBuffer 100M
  git config --global core.compression 0

  git merge origin/${BUILD_GIT_BRANCH} -m "Merge remote" &&
    git commit -a -m "Commit"
  echo "Final push to dev"
  git push -f
  git push origin --tags
  git push origin --all
fi

echo "${TARGET_VERSION}" > /shared/build_version.txt
