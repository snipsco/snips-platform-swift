#!/usr/bin/env bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target_dir>"
    exit 1
fi

target_dir=$1

assistant_filename="assistant-weather-EN-0.20.0-dynv2-heysnipsv4.zip"
url="https://resources.snips.ai/assistants/$assistant_filename"

if [ ! -f $target_dir/assistant/assistant.json ]; then
    echo "will download from $url"
    pushd $target_dir
    curl -O $url
    unzip -q $assistant_filename
    rm $assistant_filename
    popd
    echo "done."
else
    echo "assistant already present."
fi
