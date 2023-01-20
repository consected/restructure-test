RUBY_V=2.7.6
GIT_EMAIL=youremail
TEST_GIT_BRANCH=develop
REPO_URL="https://github.com/somerepo"
DOCS_REPO_URL="https://github.com/somerepo_for_docs"
# For example, to test the consected/restructure repo
# REPO_URL="https://github.com/consected/restructure"
# DOCS_REPO_URL="https://github.com/consected/restructure-docs"

# If running as a development container, specify the follow repo
# APPS_REPO_URL=https://github.com/somerepo_for_apps
# For example:
# APPS_REPO_URL=https://github.com/consected/restructure-apps.git

# VSCode can connect to the container directly when running. 
# For direct SSH connections, specify
# SSH_USERNAME=root
# then copy the id_rsa.pub file to the ./shared directory
# Run `./test bash`
# You should be able to `ssh -p 2022 -i ~/.ssh/id_rsa root@localhost`


DB_USER=$(whoami)
DB_PASSWORD=root

# The geckodriver is required for Selenium to run against Firefox.
# See geckodriver releases at: https://github.com/mozilla/geckodriver/releases
# It is possible that a different version will be required based on the architecture of the machine. Others available are
# geckodriver-v0.32.0-linux-aarch64.tar.gz
# geckodriver-v0.32.0-linux32.tar.gz
# geckodriver-v0.32.0-linux64.tar.gz
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

DB_NAME=restr
TEST_DB_NAME=${DB_NAME}_test
DB_USER=$(whoami)
DB_PASSWORD=root
