#!/bin/bash
# Refresh the vendored shared/lib/*.sh files from a sibling restructure-ops checkout.
# These files are checked into git here (not fetched at Docker build time, since CI may only
# have this repo checked out) - run this manually whenever restructure-ops's shared/lib changes.
#
# Usage: ./sync-ops-lib.sh [path-to-restructure-ops]
#   Defaults to ../restructure-ops if no path is given (or $OPS_REPO_DIR if set).

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
OPS_REPO_DIR="${1:-${OPS_REPO_DIR:-${SCRIPT_DIR}/../restructure-ops}}"

# Files vendored verbatim from restructure-ops - keep this list in sync with shared/lib/.
VENDORED_FILES=(rbenv.sh git-config.sh)

if [ ! -d "${OPS_REPO_DIR}/shared/lib" ]; then
  echo "Could not find a restructure-ops checkout at '${OPS_REPO_DIR}'." >&2
  echo "Pass its path as an argument, or set OPS_REPO_DIR." >&2
  exit 1
fi

for f in "${VENDORED_FILES[@]}"; do
  src="${OPS_REPO_DIR}/shared/lib/${f}"
  dest="${SCRIPT_DIR}/shared/lib/${f}"

  if [ ! -f "${src}" ]; then
    echo "Source file missing, skipping: ${src}" >&2
    continue
  fi

  # Rebuild dest from the ops source verbatim, just inserting a vendoring note after its first
  # line (the "shellcheck shell=bash" directive) so ops's own file-level description is kept as-is.
  {
    head -n 1 "${src}"
    echo "# VENDORED from restructure-ops:shared/lib/${f} - do not edit directly."
    echo "# Refresh with ./sync-ops-lib.sh (run from the restructure-test repo root)."
    tail -n +2 "${src}"
  } > "${dest}.new"

  if diff -q "${dest}" "${dest}.new" > /dev/null 2>&1; then
    echo "Unchanged: ${f}"
    rm -f "${dest}.new"
    continue
  fi

  echo "Updating: ${f}"
  mv "${dest}.new" "${dest}"
done

echo "Done. Review the diff, update version numbers/build-vars if needed, then commit."
