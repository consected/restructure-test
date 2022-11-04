RUBY_V=2.7.5
GIT_EMAIL=youremail
TEST_GIT_BRANCH=develop
REPO_URL="https://github.com/somerep"
DOCS_REPO_URL="https://github.com/somerep_for_docs"

DB_USER=$(whoami)
DB_PASSWORD=root

# See geckodriver releases at: https://github.com/mozilla/geckodriver/releases
GECKODRIVER=https://github.com/mozilla/geckodriver/releases/download/v0.23.0/geckodriver-v0.23.0-linux64.tar.gz

# Uncomment if you want to drop and recreate the test database on startup
# DROP_DATABASE=true
# Uncomment if you want to prevent static analysis tests such as brakeman from running
# NO_BRAKEMAN=true
# Uncomment to specify the specs to run
# RUN_SPECS=spec/features
