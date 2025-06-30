#!/bin/bash

# Install neccessary tools
sudo apt install -y reprepro gnupg

mkdir -p dist/conf
cat <<EOF >dist/conf/distributions
Origin: $ORIGIN
Label: clang-android
Codename: $RELEASE
Arch: $ARCH
Components: 
UDebComponents: 
Description: 
EOF

if [ "$GPG_SIGNING_KEY" ]; then
	KEY_OWNER=$(echo "$GPG_SIGNING_KEY" | gpg --import 2>&1 | grep -i ": public key " | awk -F'"' '{print $2}')
	if [ ! "$MAINTAINER" ]; then
		MAINTAINER=$KEY_OWNER
	fi
	KEY_FINGERPRINT=$(gpg --list-secret-key --with-subkey-fingerprint | grep -A3 "$MAINTAINER" | tail -2)
	echo "SignWith: $KEY_FINGERPRINT" >>dist/conf/distributions
fi
cat dist/conf/distributions

SIGNKEY=$(grep SignWith dist/conf/distributions | awk "{print $2}" || :)
WORKDIR=$(pwd)/dist

cd $WORKDIR

# Create repository
for changes in ../build/clang-r*/*.changes; do
	[ "$changes" = '../build/clang-r*/*.changes' ] && continue
	if [ "$SIGNKEY" ]; then
		[ "$SIGNKEY" = "yes" ] && sign_key= || sign_key=$SIGNKEY
		cd "$(dirname "$changes")"
		./debsign.sh ${SIGNKEY:+-k "$sign_key"} "$changes"
		cd $WORKDIR
	fi

	reprepro include "$RELEASE" "$changes"
done
