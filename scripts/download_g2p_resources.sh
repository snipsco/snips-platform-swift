#!/usr/bin/env bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target_dir>"
exit 1
fi

target_dir=$1

g2p_filename="g2p-0.58.4-97b0010.zip"
url="https://resources.snips.ai/injection/$g2p_filename"

if [ ! -f $target_dir/snips-g2p-resources/README.md ]; then
    echo "will download from $url"
    pushd $target_dir
    curl -O $url
    unzip -q $g2p_filename
    rm $g2p_filename
    popd
    echo "done."
else
    echo "g2p already present."
fi
