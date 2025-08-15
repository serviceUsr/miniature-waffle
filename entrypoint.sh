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
# snapshot containers don't ship with the SDK to save bandwidth
# run setup.sh to download and extract the SDK
[ ! -f setup.sh ] || bash setup.sh
endgroup

FEEDNAME="${FEEDNAME:-action}"
BUILD_LOG="${BUILD_LOG:-1}"

# if [ -n "$KEY_BUILD" ]; then
# 	echo "$KEY_BUILD" > key-build
# 	CONFIG_SIGNED_PACKAGES="y"
# fi

# if [ -n "$PRIVATE_KEY" ]; then
# 	echo "$PRIVATE_KEY" > private-key.pem
# 	CONFIG_SIGNED_PACKAGES="y"
# fi

# if [ -z "$NO_DEFAULT_FEEDS" ]; then
# 	sed \
# 		-e 's,https://git.openwrt.org/feed/,https://github.com/openwrt/,' \
# 		-e 's,https://git.openwrt.org/openwrt/,https://github.com/openwrt/,' \
# 		-e 's,https://git.openwrt.org/project/,https://github.com/openwrt/,' \
# 		feeds.conf.default > feeds.conf
# fi

# echo "src-link $FEEDNAME /feed/" >> feeds.conf

# ALL_CUSTOM_FEEDS="$FEEDNAME "
# #shellcheck disable=SC2153
# for EXTRA_FEED in $EXTRA_FEEDS; do
# 	echo "$EXTRA_FEED" | tr '|' ' ' >> feeds.conf
# 	ALL_CUSTOM_FEEDS+="$(echo "$EXTRA_FEED" | cut -d'|' -f2) "
# done

# group "feeds.conf"
# cat feeds.conf
# endgroup

# group "feeds update -a"
# ./scripts/feeds update -a
# endgroup

# group "make defconfig"
# make defconfig
# endgroup

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
endgroup


if [[ -n "$NO_DEFAULT_REPOS" ]]; then
	group "empty repositories file"
	echo "emptying repositories file"
	echo "" > $REPO_FILE
	endgroup
fi

if [[ -n "$CUSTOM_REPO" ]]; then
	echo "$CUSTOM_REPO" | cat - $REPO_FILE > temp && mv temp $REPO_FILE
fi

group "cat repo file"
cat $REPO_FILE
endgroup

# group "ls -l /"
# ls -l /
# endgroup


# group "ls -lR"
# pwd
# ls -lR
# endgroup

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

make image \
	PROFILE="$PROFILE" \
	PACKAGES="$PACKAGES" \
	FILES="$FILES" \
	EXTRA_IMAGE_NAME="$EXTRA_IMAGE_NAME" \
	DISABLED_SERVICES="$DISABLED_SERVICES" \
	ADD_LOCAL_KEY="$ADD_LOCAL_KEY" \
	ROOTFS_PARTSIZE="$ROOTFS_PARTSIZE" || RET=$?

# NO_DEFAULT_REPOS

# if [ -z "$PACKAGES" ]; then
# 	# compile all packages in feed
# 	for FEED in $ALL_CUSTOM_FEEDS; do
# 		group "feeds install -p $FEED -f -a"
# 		./scripts/feeds install -p "$FEED" -f -a
# 		endgroup
# 	done

# 	RET=0

# 	make \
# 		BUILD_LOG="$BUILD_LOG" \
# 		CONFIG_SIGNED_PACKAGES="$CONFIG_SIGNED_PACKAGES" \
# 		IGNORE_ERRORS="$IGNORE_ERRORS" \
# 		CONFIG_AUTOREMOVE=y \
# 		V="$V" \
# 		-j "$(nproc)" || RET=$?
# else
# 	# compile specific packages with checks
# 	for PKG in $PACKAGES; do
# 		for FEED in $ALL_CUSTOM_FEEDS; do
# 			group "feeds install -p $FEED -f $PKG"
# 			./scripts/feeds install -p "$FEED" -f "$PKG"
# 			endgroup
# 		done

# 		group "make package/$PKG/download"
# 		make \
# 			BUILD_LOG="$BUILD_LOG" \
# 			IGNORE_ERRORS="$IGNORE_ERRORS" \
# 			"package/$PKG/download" V=s
# 		endgroup

# 		group "make package/$PKG/check"
# 		make \
# 			BUILD_LOG="$BUILD_LOG" \
# 			IGNORE_ERRORS="$IGNORE_ERRORS" \
# 			"package/$PKG/check" V=s 2>&1 | \
# 				tee logtmp
# 		endgroup

# 		RET=${PIPESTATUS[0]}

# 		if [ "$RET" -ne 0 ]; then
# 			echo_red   "=> Package check failed: $RET)"
# 			exit "$RET"
# 		fi

# 		badhash_msg="HASH does not match "
# 		badhash_msg+="|HASH uses deprecated hash,"
# 		badhash_msg+="|HASH is missing,"
# 		if grep -qE "$badhash_msg" logtmp; then
# 			echo "Package HASH check failed"
# 			exit 1
# 		fi

# 		PATCHES_DIR=$(find /feed -path "*/$PKG/patches")
# 		if [ -d "$PATCHES_DIR" ] && [ -z "$NO_REFRESH_CHECK" ]; then
# 			group "make package/$PKG/refresh"
# 			make \
# 				BUILD_LOG="$BUILD_LOG" \
# 				IGNORE_ERRORS="$IGNORE_ERRORS" \
# 				"package/$PKG/refresh" V=s
# 			endgroup

# 			if ! git -C "$PATCHES_DIR" diff --quiet -- .; then
# 				echo "Dirty patches detected, please refresh and review the diff"
# 				git -C "$PATCHES_DIR" checkout -- .
# 				exit 1
# 			fi

# 			group "make package/$PKG/clean"
# 			make \
# 				BUILD_LOG="$BUILD_LOG" \
# 				IGNORE_ERRORS="$IGNORE_ERRORS" \
# 				"package/$PKG/clean" V=s
# 			endgroup
# 		fi

# 		FILES_DIR=$(find /feed -path "*/$PKG/files")
# 		if [ -d "$FILES_DIR" ] && [ -z "$NO_SHFMT_CHECK" ]; then
# 			find "$FILES_DIR" -name "*.init" -exec shfmt -w -sr -s '{}' \;
# 			if ! git -C "$FILES_DIR" diff --quiet -- .; then
# 				echo "init script must be formatted. Please run through shfmt -w -sr -s"
# 				git -C "$FILES_DIR" checkout -- .
# 				exit 1
# 			fi
# 		fi

# 	done

# 	make \
# 		-f .config \
# 		-f tmp/.packagedeps \
# 		-f <(echo "\$(info \$(sort \$(package-y) \$(package-m)))"; echo -en "a:\n\t@:") \
# 			| tr ' ' '\n' > enabled-package-subdirs.txt

# 	RET=0

# 	for PKG in $PACKAGES; do
# 		if ! grep -m1 -qE "(^|/)$PKG$" enabled-package-subdirs.txt; then
# 			echo "::warning file=$PKG::Skipping $PKG due to unsupported architecture"
# 			continue
# 		fi

# 		make \
# 			BUILD_LOG="$BUILD_LOG" \
# 			IGNORE_ERRORS="$IGNORE_ERRORS" \
# 			CONFIG_AUTOREMOVE=y \
# 			V="$V" \
# 			-j "$(nproc)" \
# 			"package/$PKG/compile" || {
# 				RET=$?
# 				break
# 			}
# 	done
# fi

# if [ "$INDEX" = '1' ];then
# 	group "make package/index"
# 	make package/index
# 	endgroup
# fi

if [ -d bin/ ]; then
	mv bin/ /artifacts/
fi

exit "$RET"
