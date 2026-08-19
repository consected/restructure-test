# shellcheck shell=bash
# VENDORED from restructure-ops:shared/lib/rbenv.sh - do not edit directly.
# Refresh with ./sync-ops-lib.sh (run from the restructure-test repo root).
# Shared rbenv helpers, sourced by both build-container.sh (image build time) and
# shared/build-restructure.sh (container run time), to avoid duplicating this logic in each place.

# Ensure rbenv has ${1} installed and active (via .ruby-version) in the current directory.
# Installs it if missing; exits the script on failure.
function ensure_ruby_version() {
  local version=$1
  if [ -z "${version}" ]; then
    echo "ensure_ruby_version requires a version argument" >&2
    exit 1
  fi

  rbenv local "${version}"
  if [ "$(rbenv version-name)" == "${version}" ] && ruby --version 2> /dev/null | grep -q "${version}"; then
    return 0
  fi

  echo "Installing ruby ${version} via rbenv"
  git -C "$(rbenv root)/plugins/ruby-build" pull
  rbenv install --skip-existing "${version}"
  rbenv local "${version}"
  rbenv global "${version}"

  if [ "$(rbenv version-name)" != "${version}" ]; then
    echo "Failed to install or activate ruby ${version} (rbenv reports $(rbenv version-name))" >&2
    exit 1
  fi
}

# Clone rbenv + ruby-build into HOME and wire up the shell profile. Only needed once, at image
# build time (see build-container.sh) - a fresh checkout has no rbenv installation at all yet.
function install_rbenv() {
  git clone https://github.com/rbenv/rbenv.git "${HOME}/.rbenv"
  "${HOME}/.rbenv/bin/rbenv" init
  echo 'eval "$(rbenv init -)"' >> "${HOME}/.bash_profile"
  export PATH="${HOME}/.rbenv/bin:${HOME}/.rbenv/shims:${PATH}"
  eval "$(rbenv init -)"
  . "${HOME}/.bash_profile"
  mkdir -p "$(rbenv root)/plugins"
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build"
  rbenv install --list
  rbenv rehash
}
