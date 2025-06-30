#!/bin/bash

# Install neccessary tools
sudo apt install -y reprepro gnupg

SIGNKEY=$(grep SignWith dist/conf/distributions | awk '{print $2}' || :)
WORKDIR=$(pwd)

# Create repository
for changes in build/clang-r*/*.changes; do
	if [ "$SIGNKEY" ]; then
		[ "$SIGNKEY" = "yes" ] && sign_key= || sign_key=$SIGNKEY
		cd $(dirname $changes)
		./debsign.sh ${SIGNKEY:+-k "$sign_key"} "$changes"
		cd $pwd
	fi

	reprepro include "$RELEASE" "$changes"
done
