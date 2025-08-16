#!/bin/bash

set -ef

GROUP=

group() {
	endgroup
	echo "::group::  $1"
	GROUP=1
}

endgroup() {
	if [ -n "$GROUP" ]; then
		echo "::endgroup::"
	fi
	GROUP=
}

trap 'endgroup' ERR

group "bash setup.sh"
# snapshot containers don't ship with the imagebuilder to save bandwidth
# run setup.sh to download and extract the SDK
[ ! -f setup.sh ] || bash setup.sh
endgroup

FEEDNAME="${FEEDNAME:-action}"
BUILD_LOG="${BUILD_LOG:-1}"

RET=0

group "find repositories file"
REPO_FILE=
if [[ -f repositories ]]; then
	REPO_FILE=repositories
elif [[ -f repositories.conf ]]; then
	REPO_FILE="repositories.conf"
else
	echo "::warning no repositories file found"
fi
echo "$REPO_FILE"
cat $REPO_FILE
endgroup

if [[ -n "$NO_DEFAULT_REPOS" ]]; then
	group "empty repositories file"
	echo "emptying repositories file"
	echo "" > $REPO_FILE
	endgroup
fi

if [[ -n "$CUSTOM_REPO" ]]; then
	echo "prepend repositories file with CUSTOM_REPO"
	echo "$CUSTOM_REPO" | cat - $REPO_FILE > temp && mv temp $REPO_FILE
fi

group "cat repo file"
cat $REPO_FILE
endgroup

if [[ -n "$KEYS_DIR" ]]; then
	group "copy custom keys"
	cp -av /keys/. /builder/keys/
	endgroup
fi

FILES=""
if [[ -n "$FILES_DIR" ]]; then
	group "list hardcoded files"
	ls -lR /files/
	endgroup
	FILES=/files/
fi

group "ls -lR keys"
ls -lR keys
endgroup


for profile in $PROFILE; do
	group "building ${profile}"
	make image \
		PROFILE="$profile" \
		PACKAGES="$PACKAGES" \
		FILES="$FILES" \
		EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME" \
		DISABLED_SERVICES="$DISABLED_SERVICES" \
		ADD_LOCAL_KEY="$ADD_LOCAL_KEY" \
		ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE" || RET=$?
	endgroup

	if [ "$RET" -ne 0 ]; then
		echo "::error => building $profile failed"
		echo_red   "=> Package check failed: $RET)"
		exit "$RET"
	fi
done

if [ -d bin/ ]; then
	mv bin/ /artifacts/
fi

exit "$RET"
