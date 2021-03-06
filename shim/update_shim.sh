#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Automation script to create specs to build cc-shim
# Default: Build is the one specified in file configure.ac
# located at the root of the repository.
set -x
AUTHOR=${AUTHOR:-$(git config user.name)}
AUTHOR_EMAIL=${AUTHOR_EMAIL:-$(git config user.email)}

source ../versions.txt
VERSION=${1:-$cc_shim_version}
VERSION_DEB_TRANSFORM=$(echo $VERSION | tr -d '-')

hash_tag=$cc_shim_hash
short_hashtag="${hash_tag:0:7}"
# If there is no tag matching $VERSION we'll get $VERSION as the reference
[ -z "$hash_tag" ] && hash_tag=$VERSION || :

OBS_PUSH=${OBS_PUSH:-false}
OBS_SHIM_REPO=${OBS_SHIM_REPO:-home:clearcontainers:clear-containers-3-staging/cc-shim}

GO_VERSION=${GO_VERSION:-"1.8.3"}

echo "Running: $0 $@"
echo "Update cc-shim $VERSION: ${hash_tag:0:7}"

function changelog_update {
    d=$(date +"%a, %d %b %Y %H:%M:%S %z")
    git checkout debian.changelog
    cp debian.changelog debian.changelog-bk
    cat <<< "cc-shim ($VERSION) stable; urgency=medium

  * Update cc-shim $VERSION ${hash_tag:0:7}

 -- $AUTHOR <$AUTHOR_EMAIL>  $d
" > debian.changelog
    cat debian.changelog-bk >> debian.changelog
    rm debian.changelog-bk
}
changelog_update $VERSION

sed "s/@VERSION@/$VERSION/g;" cc-shim.spec-template > cc-shim.spec
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" cc-shim.dsc-template > cc-shim.dsc
sed -e "s/@VERSION_DEB_TRANSFORM@/$VERSION_DEB_TRANSFORM/g;" -e "s/@HASH_TAG@/$short_hashtag/g;" debian.control-template > debian.control
sed "s/@VERSION@/$VERSION/g;" _service-template > _service

# Update and package OBS
if [ "$OBS_PUSH" = true ]
then
    temp=$(basename $0)
    TMPDIR=$(mktemp -d -t ${temp}.XXXXXXXXXXX) || exit 1
    osc co "$OBS_SHIM_REPO" -o $TMPDIR
    mv cc-shim.spec \
        cc-shim.dsc \
        _service \
        debian.control \
        $TMPDIR
    cp debian.changelog \
        debian.rules \
        debian.compat \
        $TMPDIR
    cd $TMPDIR
    osc addremove
    osc commit -m "Update cc-shim $VERSION: ${hash_tag:0:7}"
fi
