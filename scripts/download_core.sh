#!/bin/sh -ex

 : ${PROJECT_DIR:?"${0##*/} must be invoked as part of an Xcode script phase"}

set -e

VERSION="0.57.2"
SYSTEM=$(echo $1 | tr '[:upper:]' '[:lower:]')
LIBRARY_NAME=libsnips_megazord
LIBRARY_NAME_A=${LIBRARY_NAME}.a
LIBRARY_NAME_H=${LIBRARY_NAME}.h
OUT_DIR=${PROJECT_DIR}/Dependencies/${SYSTEM}

if [ -z "$TARGET_BUILD_TYPE" ]; then
TARGET_BUILD_TYPE=$(echo ${CONFIGURATION} | tr '[:upper:]' '[:lower:]')
fi

if [ "${SYSTEM}" != "ios" ]; then
    echo "Only ios is supported."
    exit 1
fi

mkdir -p ${OUT_DIR}

install_remote_core () {
    local filename=snips-platform-${SYSTEM}.${VERSION}.tgz
    local url=https://s3.amazonaws.com/snips/snips-platform-dev/${filename}

    rm -f ${OUT_DIR}/*
    if ! core_is_present || ! core_is_up_to_date; then
        echo "Will download '${filename}'"
        $(cd ${OUT_DIR} && curl -s ${url} | tar zxv)
    fi
}

install_local_core () {
    # TODO: Find a better way to retrieve root_dir
    local root_dir=${PROJECT_DIR}/../../../
    local target_dir=${root_dir}/target/

    if [ ! -e ${root_dir}/Makefile ]; then
        return 1
    fi

    make -C ${root_dir} package-megazord-dependencies-ios

    rm -f ${OUT_DIR}/*

    if [ ${SYSTEM} == ios ]; then
        echo "Using iOS local build"
        local archs_array=( ${ARCHS} )

        for arch in "${archs_array[@]}"; do
            if [ ${arch} = arm64 ]; then
                local arch=aarch64
            fi
            local library_path=${target_dir}/${arch}-apple-ios/${TARGET_BUILD_TYPE}/${LIBRARY_NAME_A}
            if [ ! -e ${library_path} ]; then
                return 1
            fi
            cp ${library_path} ${OUT_DIR}/${LIBRARY_NAME}-${arch}.a
        done

        lipo -create `find ${OUT_DIR}/${LIBRARY_NAME}-*.a` -output ${OUT_DIR}/${LIBRARY_NAME_A}
        cp ${target_dir}/ios-universal/megazord/* ${OUT_DIR}

    else
        echo "${SYSTEM} isn't supported"
        return 1
    fi

    return 0
}

core_is_present () {
    if [ -e ${OUT_DIR}/module.modulemap ] &&
       [ -e ${OUT_DIR}/${LIBRARY_NAME_A} ] &&
       [ -e ${OUT_DIR}/${LIBRARY_NAME_H} ]; then
        return 0
    fi

    return 1
}

core_is_up_to_date () {
    local header_path = ${OUT_DIR}/${LIBRARY_NAME_H}
    local core_version=$(grep "SNIPS_VERSION" $header_path | cut -d'"' -f2)

    if [ "$core_version" = ${VERSION} ]; then
        return 0
    fi

    return 1
}

if [ "${SNIPS_USE_LOCAL_PLATFORM}" == 1 ]; then
    install_local_core && exit 0
elif [ "${SNIPS_USE_REMOTE}" == 1 ]; then
    install_remote_core && exit 0
else
    if core_is_present && core_is_up_to_date; then
        exit 0
    fi

    if ! install_local_core; then
        install_remote_core && exit 0
    fi
fi
