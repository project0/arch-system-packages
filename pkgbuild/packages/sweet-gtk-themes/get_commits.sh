#!/bin/bash
# fetch latest commits

source PKGBUILD
for k in "${_branches[@]}"; do
    git ls-remote -q --refs -h https://github.com/EliverLara/Sweet.git | grep -E "${k}$" | cut -d$'\t' -f 1 -z
    echo " # $k"
done