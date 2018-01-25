#!/usr/bin/env bash

set -e

NEW_VERSION=$1

if [ -z $NEW_VERSION ]; then
    echo "Usage: $0 NEW_VERSION"
    exit 1
fi

SPLIT_VERSION=( ${NEW_VERSION//./ } )
if [ ${#SPLIT_VERSION[@]} -ne 3 ]; then
  echo "Version number is invalid (must be of the form x.y.z)"
  exit 1
fi

((SPLIT_VERSION[1]++))
NEXT_NEW_VERSION="${SPLIT_VERSION[0]}.${SPLIT_VERSION[1]}.${SPLIT_VERSION[2]}"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

perl -p -i -e "s/^VERSION=\".*\"\$/VERSION=\"$NEW_VERSION\"/g" $SCRIPTPATH/download_core.sh
perl -p -i -e "s/s\.version = '.*'/s\.version = '$NEW_VERSION'/g" $SCRIPTPATH/../SnipsPlatform.podspec
