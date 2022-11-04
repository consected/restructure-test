RUBY_V=2.7.5
GIT_EMAIL=youremail
TEST_GIT_BRANCH=develop
REPO_URL="https://github.com/somerep"
DOCS_REPO_URL="https://github.com/somerep_for_docs"

DB_USER=$(whoami)
DB_PASSWORD=root

# The geckodriver is required for Selenium to run against Firefox.
# See geckodriver releases at: https://github.com/mozilla/geckodriver/releases
# It is possible that a different version will be required based on the architecture of the machine. Others available are
# geckodriver-v0.32.0-linux-aarch64.tar.gz
# geckodriver-v0.32.0-linux-aarch64.tar.gz.asc
# geckodriver-v0.32.0-linux32.tar.gz
# geckodriver-v0.32.0-linux32.tar.gz.asc
# geckodriver-v0.32.0-linux64.tar.gz
# geckodriver-v0.32.0-linux64.tar.gz.asc
# geckodriver-v0.32.0-macos-aarch64.tar.gz
# geckodriver-v0.32.0-macos.tar.gz
# geckodriver-v0.32.0-win-aarch64.zip
# geckodriver-v0.32.0-win32.zip

GECKODRIVER=https://github.com/mozilla/geckodriver/releases/download/v0.32.0/geckodriver-v0.32.0-linux64.tar.gz

# Uncomment if you want to drop and recreate the test database on startup
# DROP_DATABASE=true
# Uncomment if you want to prevent static analysis tests such as brakeman from running
# NO_BRAKEMAN=true
# Uncomment to specify the specs to run
# RUN_SPECS=spec/features
