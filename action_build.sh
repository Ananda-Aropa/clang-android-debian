#!/bin/bash
# shellcheck disable=2086,2103,2164,2317

cd "$(dirname "$0")"
WORKDIR=$(pwd)
SOURCE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86"
# MAINTAINER="Bùi Gia Viện <shadichy@blisslabs.org>"
# ARCH="amd64"
# RELEASE="unstable"
NAME=clang-android

# avoid command failure
exit_check() { [ "$1" = 0 ] || exit "$1"; }
trap 'exit_check $?' EXIT

# # Update packages
# sudo apt update && apt upgrade -y

# # Install debhelper
# yes | sudo apt install -y debhelper cryptsetup pkg-kde-tools pkexec rsync git wget || : >/dev/null 2>&1

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
dir=build/clang-r$rev
mkdir -p $dir
sudo mount -t tmpfs tmpfs $dir
mv $latest $dir/clang
cd $dir

# Copy files
cp $WORKDIR/{docker_build.sh,Dockerfile} .

# Env
VERSION=$(./clang/bin/clang --version | grep version | awk -F " clang version " '{print $2}' | cut -d ' ' -f 1)-$rev

# Generate debian config
mkdir -p debian/source
echo "3.0 (quilt)" >debian/source/format
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
cat <<EOF >debian/rules
#!/usr/bin/make -f

%:
	dh \$@

override_dh_auto_test:

override_dh_dwz:

override_dh_strip:

override_dh_shlibdeps:

EOF
cat <<EOF >debian/install
clang opt/android
EOF
dpkg-architecture -A $ARCH >.build_env
echo "DEB_ARCH='$ARCH'" >>.env
echo "DEB_BUILD_ARGS='-b'" >>.env

# Build
docker buildx create --use --name debian-deb-$ARCH-$rev --buildkitd-flags '--allow-insecure-entitlement security.insecure'
PLATFORM=$ARCH
case "$PLATFORM" in
i386) PLATFORM=386 ;;
arm64) PLATFORM=arm64/v8 ;;
*) ;;
esac

{
	sleep 60
	rm -rf clang
} &

docker buildx build --builder debian-deb-$ARCH-$rev --platform linux/$PLATFORM -f ./Dockerfile -t debian-$ARCH-$rev --allow security.insecure --output type=tar,dest=build-$ARCH-$rev.tar --rm .

docker buildx rm -f debian-deb-$ARCH-$rev
rm -rf clang

# Export
sudo tar \
	-C . \
	-psxf build-$ARCH-$rev.tar \
	--wildcards --no-anchored "${NAME}_${VERSION}_${ARCH}.*"
ls ${NAME}_${VERSION}_${ARCH}.*
sudo rm -rf build-$ARCH-$rev.tar

cd $WORKDIR
