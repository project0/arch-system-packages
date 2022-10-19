#!/bin/bash
set -euo pipefail

GIT_REPO=${GIT_REPO-}
GIT_BRANCH=${GIT_BRANCH-main}
GPG_FINGERPRINT=${GPG_FINGERPRINT-}

test -n "$GIT_REPO" || (echo "Fatal: empty GIT_REPO"; exit 1)
test -n "$GIT_BRANCH" || (echo "Fatal: empty GIT_BRANCH"; exit 1)
test -n "$GPG_FINGERPRINT" || (echo "Fatal: empty GPG_FINGERPRINT"; exit 1)

DOMAIN=arch.packages.project0.de
export REPO_URL=https://${DOMAIN}
export PKGDEST=$(pwd)/dist-git
export GPG_FINGERPRINT

make clean
(
  mkdir -p "$PKGDEST"
  cd "$PKGDEST"

  git init -b "${GIT_BRANCH}"
  # set up a remote
  git remote add origin "${GIT_REPO}"
)

# generate internal package repo config
make -s repo-conf > pkgbuild/system/base/base-config.pacman.repo-gen.conf
# build packages
make all

# generate readme and add scripts
make -s repo-readme > "$PKGDEST/README.md"
cp -Rva bin/ "$PKGDEST/bin"
make -s bootstrap-script > "$PKGDEST/bin/bootstrap.sh"

# cname file is required for github pages
echo "$DOMAIN" > "$PKGDEST/CNAME"

gpg -a --export "$GPG_FINGERPRINT" > "${PKGDEST}/key.asc"

(
  cd "$PKGDEST"
  git add .
  git commit -m "Update"
  git push -f -u origin "${GIT_BRANCH}"
)