#!/bin/bash

SCRIPT_DIR=$(dirname $0)
cd ${SCRIPT_DIR}
ADMIN_GRP=wheel
RE_ROOT=/output
GIT_CRED="${HOME}/.git-credentials"
NETRC="${HOME}/.netrc"

source /etc/profile
source ~/.bash_profile

# if [ $(whoami) != 'root' ]; then
#   echo "Must run as root! Re run with sudo $0" >&2
#   exit 1
# fi

function get_config() {
  if [ -z $1 ]; then
    echo 'Argument must be a config variable name' >&2
    return 1
  fi

  local config_file="${HOME}/config/$1"
  if [ -s "${config_file}" ]; then
    readonly $1=$(cat "${config_file}")
    echo "${!1}"
  else
    return 1
  fi
}

function save_config() {
  if [ -z $2 ]; then
    echo 'Arguments must be a config variable name and value' >&2
    return 1
  fi

  local val=$2
  local config_file="${HOME}/config/$1"
  mkdir -p ${HOME}/config
  echo "${val}" > "${config_file}"
  unset $1
  readonly $1=$(cat "${config_file}")
  echo $1=${!1}
}

cd ${RE_ROOT}

cd ${SCRIPT_DIR}

get_config GIT_EMAIL
get_config GIT_FIRSTNAME
get_config GIT_LASTNAME
get_config GH_BASEURL

if [ "${GIT_EMAIL}" ] && [ "${GIT_FIRSTNAME}" ] && [ "${GIT_LASTNAME}" ] && [ "${GH_BASEURL}" ] && [ "$1" != 'reset' ]; then

  git config --global user.email "${GIT_EMAIL}"
  git config --global user.name "${GIT_FIRSTNAME} ${GIT_LASTNAME}"
  git config --replace-all --global credential.helper store
  
else
  echo 'Enter the following information for Git'
  read -p 'Email address: ' email
  read -p 'First name: ' firstname
  read -p 'Last name: ' lastname
  read -p 'Github username: ' ghusername
  read -p 'Github access key: ' ghaccesskey
  if [ "${REPO_BASE_URL}" ]; then
    ghbaseurl="${REPO_BASE_URL}"
  else
    read -p "Github base URL (for example https://github.com/consected): " ghbaseurl
  fi
  save_config GIT_EMAIL "${email}"
  save_config GIT_FIRSTNAME "${firstname}"
  save_config GIT_LASTNAME "${lastname}"
  save_config GH_BASEURL "${ghbaseurl}"

  git config --global user.email "${GIT_EMAIL}"
  git config --global user.name "${GIT_FIRSTNAME} ${GIT_LASTNAME}"
  git config --replace-all --global credential.helper store

  echo "https://${ghusername}:${ghaccesskey}@${GH_BASEURL/https:\/\//}" > "${GIT_CRED}"
  echo "machine github.com login ${ghusername} password ${ghaccesskey}" > "${NETRC}"
  chmod 600 "${NETRC}"
  chmod 600 "${GIT_CRED}"
fi

sudo mkdir -p ${RE_ROOT}
sudo chgrp ${ADMIN_GRP} ${RE_ROOT}
sudo chmod o+rwx,g+rwx ${RE_ROOT}

cd ${RE_ROOT}

# Run each line in turn and enter github credentials where requested
for r in restructure restructure-apps restructure-docs; do
  sudo rm -rf ${r}
  git clone ${GH_BASEURL}/${r}.git
  sudo chgrp --recursive ${ADMIN_GRP} ${r}
done
