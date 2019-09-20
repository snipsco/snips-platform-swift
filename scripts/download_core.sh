#!/usr/bin/env bash

VERSION="0.64.0-SNAPSHOT"
LIBRARY_NAME=libsnips_megazord
LIBRARY_NAME_A_IOS=${LIBRARY_NAME}-ios.a
LIBRARY_NAME_A_MACOS=${LIBRARY_NAME}-macos.a
LIBRARY_NAME_H=${LIBRARY_NAME}.h

: ${PROJECT_DIR:?"${0##*/} must be invoked as part of an Xcode script phase."}

OUT_DIR=${PROJECT_DIR}/Dependencies/

install_remote_core() {
    echo "Trying remote installation"

    local filename=snips-platform-cocoa.${VERSION}.tgz
    local url=https://s3.amazonaws.com/snips/snips-platform-dev/${filename} # TODO: resources.snips.ai or whatever

    echo "Will download and decompress '${filename}' into '${OUT_DIR}'"
    if curl --output /dev/null --silent --head --fail "$url"; then
        $(cd "${OUT_DIR}" && curl -s ${url} | tar zxv)
    else
        echo "Version ${VERSION} doesn't seem to have been released yet" >&2
        echo "Could not find any file at '${url}'" >&2
        echo "Please file issue on 'https://github.com/snipsco/snips-issues' if you believe this is an issue" >&2
        return 1
    fi
}

core_is_present() {
    echo "Checking if core is present and complete"

    local files_to_check=(
        "${OUT_DIR}/${LIBRARY_NAME_H}"
        "${OUT_DIR}/module.modulemap"
    )
    if [[ -z ${SNIPS_TARGET_PLATFORM} ]] || [[ ${SNIPS_TARGET_PLATFORM} = "ios" ]]; then
        files_to_check+=("${OUT_DIR}/${LIBRARY_NAME_A_IOS}")
    fi
    if [ -z ${SNIPS_TARGET_PLATFORM} ] || [[ ${SNIPS_TARGET_PLATFORM} = "macos" ]]; then
        files_to_check+=("${OUT_DIR}/${LIBRARY_NAME_A_MACOS}")
    fi
    
    for file in "${files_to_check[@]}"; do
        if [ ! -e "${file}" ]; then
            echo "Core isn't complete" >&2
            echo "Missing file '$file'" >&2
            return 1
        fi
    done

    echo "Core is present"
    return 0
}

core_is_up_to_date() {
    echo "Checking if core is up-to-date"

    local header_path=${OUT_DIR}/${LIBRARY_NAME_H}
    local core_version=$(grep "SNIPS_VERSION" "${header_path}" | cut -d'"' -f2)

    if [[ "$core_version" = "${VERSION}" ]]; then
        echo "Core is up-to-date"
        return 0
    fi

    echo "Found version ${core_version}, expected version ${VERSION}" >&2
    return 1
}

main() {
    if [[ -n "${SNIPS_USE_LOCAL}" ]]; then
        echo "SNIPS_USE_LOCAL is set. Will try local installation only"
        return 0
    fi
    
    if [[ -n "${SNIPS_FORCE_REINSTALL}" ]]; then
        echo "SNIPS_FORCE_REINSTALL is set. Skipping checks and reinstalling core"
    else
        if core_is_present && core_is_up_to_date; then
            echo "Core seems present and up-to-date !"
            return 0
        fi
    fi

    mkdir -p "${OUT_DIR}"
    echo "Cleaning '${OUT_DIR}' content"
    rm -f "${OUT_DIR}/*"

    install_remote_core && return 0
}

main "$@" || exit 1
