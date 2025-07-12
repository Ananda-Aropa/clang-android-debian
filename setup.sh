#!/bin/bash
# shellcheck disable=2086,2103,2164,2317

set -e

cd "$(dirname "$0")"

SOURCE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86"
ARCH=${ARCH:-amd64}
RELEASE=${RELEASE:-unstable}
MAINTAINER=$(git log -1 --pretty=format:'%an <%ae>')
NAME=clang-android

# avoid command failure
exit_check() { [ "$1" = 0 ] || exit "$1"; }
trap 'exit_check $?' EXIT

# Clone original
git clone \
	$SOURCE \
	--depth 1 \
	-b main \
	clang

rm -rf clang/{.git,clang-stable,embedded-sysroots,profiles}

latest=0
for ver in clang/clang-r*/; do
	rev=$(basename ${ver##*r})

	if [ "$rev" -gt "$latest" ]; then
		latest=$rev
	fi
done
rev=$latest

mkdir -p build
cp -rf clang/clang-r$latest/. .

rm -rf clang

# Env
VERSION=$(./bin/clang --version | grep version | awk -F " clang version " '{print $2}' | cut -d ' ' -f 1)-$rev

# Generate debian config
cat <<EOF >debian/changelog
$NAME ($VERSION) $RELEASE; urgency=medium

$(sed -n -r 's/^-/  */p' clang/clang_source_info.md)

 -- $MAINTAINER  $(date +"%a, %d %b %Y %H:%M:%S %z")

EOF
cat <<EOF >debian/control
Source: $NAME
Section: unknown
Priority: optional
Maintainer: $MAINTAINER
Rules-Requires-Root: no
Build-Depends:
 debhelper-compat (= 13),
Standards-Version: 4.7.2
Homepage: $SOURCE
Vcs-Browser: $SOURCE
Vcs-Git: $SOURCE

Package: $NAME
Architecture: $ARCH
Depends:
 \${shlibs:Depends},
 \${misc:Depends},
Description: Android Clang/LLVM Prebuilts
EOF
cat <<EOF >debian/copyright
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Source: $SOURCE
Upstream-Name: $NAME
Upstream-Contact: $MAINTAINER


Files:
 *
Copyright:
 2004 The LLVM Project
License: Apache License v2.0 with LLVM Exceptions
 Developed by:
    LLVM Team
    University of Illinois at Urbana-Champaign
    http://llvm.org

Files:
 debian/*
Copyright:
 $(date +%Y) $MAINTAINER
License: GPL-2+
EOF
