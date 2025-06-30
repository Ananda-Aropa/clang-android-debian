#!/bin/bash
# shellcheck disable=2086,2103,2164,2317

cd "$(dirname "$0")"
WORKDIR=$(pwd)
SOURCE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86"
# MAINTAINER="Bùi Gia Viện <shadichy@blisslabs.org>"
# ARCH="amd64"
# RELEASE="unstable"

# avoid command failure
exit_check() { [ "$1" = 0 ] || exit "$1"; }
trap 'exit_check $?' EXIT

# Update packages
sudo apt update && apt upgrade -y

# Install debhelper
yes | sudo apt install -y debhelper cryptsetup pkg-kde-tools pkexec rsync git wget || :

# Clone original
git clone \
	$SOURCE \
	--depth 1 \
	-b main \
	clang

mkdir -p build
for ver in clang/clang-r*/; do
	dir=build/$(basename $ver)
	mkdir -p $dir
	mv $ver $dir/clang
	cd $dir

	# Copy files
	cp $WORKDIR/{action_build.sh,Dockerfile} .

	# Generate debian config
	mkdir -p debian/source
	echo "3.0 (quilt)" >debian/source/format
	cat <<EOF >debian/changelog
clang-android ($(./clang/bin/clang --version | grep version | awk -F " clang version " '{print $2}' | cut -d ' ' -f 1)-$(basename ${ver##*r})) $RELEASE; urgency=medium

$(sed -n -r 's/^-/  */p' clang/clang_source_info.md)

 -- $MAINTAINER  $(date -u)
EOF
	cat <<EOF >debian/control
Source: clang-android
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

Package: clang-android
Architecture: $ARCH
Depends:
 $${shlibs:Depends},
 $${misc:Depends},
Description: Android Clang/LLVM Prebuilts
EOF
	cat <<EOF >debian/copyright
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Source: $SOURCE
Upstream-Name: clang-android
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
	dh $$@
EOF
	cat <<EOF >debian/install
clang opt/android
EOF
	dpkg-architecture -A $ARCH >.build_env
	echo "DEB_ARCH='$ARCH'" >>.env

	# Build
	docker buildx create --use --name debian-deb-$ARCH --buildkitd-flags '--allow-insecure-entitlement security.insecure'
	PLATFORM=$ARCH
	case "$PLATFORM" in
	i386) PLATFORM=386 ;;
	arm64) PLATFORM=arm64/v8 ;;
	*) ;;
	esac
	docker buildx build --builder debian-deb-$ARCH --platform linux/$PLATFORM -f ./Dockerfile -t debian-$ARCH --allow security.insecure --output type=tar,dest=build-$ARCH.tar .

	# Export
	mkdir -p build
	sudo tar -C build -psxf build-$ARCH.tar
	bash -c 'cp build/*.{deb,udeb,buildinfo,changes} . | :'
	sudo rm -rf build build-$ARCH.tar

	cd $WORKDIR
done
