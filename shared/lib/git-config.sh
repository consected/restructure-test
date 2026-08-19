# shellcheck shell=bash
# VENDORED from restructure-ops:shared/lib/git-config.sh - do not edit directly.
# Refresh with ./sync-ops-lib.sh (run from the restructure-test repo root).
# Git identity/buffer config shared by build-restructure.sh (container run time) and vendored
# into restructure-test, since both need identical git config before pushing/pulling large repos.

# Set standard git identity/buffer config for pushing large builds from the current directory.
# Accepts an optional git committer name, defaulting to "Restructure Build Process" (restructure-test
# passes "Restructure TEST Process" to keep test-container commits distinguishable in git history).
function configure_git_for_build() {
  local process_name="${1:-Restructure Build Process}"
  git config --global user.email "${GIT_EMAIL}"
  git config --global user.name "${process_name}"
  git config --global push.default matching
  git config --global http.postBuffer 500M
  git config --global http.maxRequestBuffer 100M
  git config --global https.postBuffer 500M
  git config --global https.maxRequestBuffer 100M
  git config --global core.compression 0
}
