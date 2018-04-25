#!/bin/sh -e

 : ${PROJECT_DIR:?"${0##*/} must be invoked as part of an Xcode script phase"}

VERSION="0.55.1-RC4"
SYSTEM=$(echo $1 | tr '[:upper:]' '[:lower:]')
LIBRARY_NAME=libsnips_megazord
LIBRARY_NAME_A=${LIBRARY_NAME}.a
HEADER_NAME_H=${LIBRARY_NAME}.h
ROOT_DIR=${PROJECT_DIR}/../../../

if [ -z ${TARGET_BUILD_TYPE} ]; then
TARGET_BUILD_TYPE=$(echo ${CONFIGURATION} | tr '[:upper:]' '[:lower:]')
fi

if [ ${SYSTEM} != ios ] && [ ${SYSTEM} != macos ]; then
    echo "Given system should be 'ios' or 'macos'."
    exit 1
fi

OUTDIR=${PROJECT_DIR}/Dependencies/${SYSTEM}
mkdir -p ${OUTDIR}

install_remote_core_platform () {
    local filename=snips-platform-${SYSTEM}.${VERSION}.tgz
    local url=https://s3.amazonaws.com/snips/snips-platform-dev/${filename}

    rm -f ${OUTDIR}/*
    if ! core_platform_is_present; then
        echo "Will download '${filename}'"
        cd ${PROJECT_DIR}/Dependencies/${SYSTEM}
        curl -s ${url} | tar zxv
    fi
}

install_local_core_platform () {
    if [ ! -e ${ROOT_DIR}/Makefile ]; then
        return 1
    fi
    echo "Attempt to use iOS local build"

    make -C ${ROOT_DIR} package-megazord-dependencies-ios

    rm -f ${OUTDIR}/*
    for arch in "${ARCHS_ARRAY[@]}"; do
        if [ ${arch} = arm64 ]; then
            local arch=aarch64
        fi
        local library_path=${ROOT_DIR}/target/${arch}-apple-ios/${TARGET_BUILD_TYPE}/${LIBRARY_NAME_A}
        if [ ! -e ${library_path} ]; then
            return 1
        fi
        cp ${library_path} ${OUTDIR}/${LIBRARY_NAME}-${arch}.a

        local kaldi_path=`find ${ROOT_DIR}/target/${arch}-apple-ios -type f -name libsnips_kaldi.dylib | head -n 1`
        if [ ! -e ${kaldi_path} ]; then
            return 1
        fi
        cp ${kaldi_path} ${OUTDIR}/libsnips_kaldi-${arch}.dylib
    done

    lipo -create `find ${OUTDIR}/${LIBRARY_NAME}-*.a` -output ${OUTDIR}/${LIBRARY_NAME_A}
    lipo -create `find ${OUTDIR}/libsnips_kaldi-*.dylib` -output ${OUTDIR}/libsnips_kaldi.dylib
    cp ${ROOT_DIR}/target/ios-universal/megazord/* ${OUTDIR}

    return 0
}

core_platform_is_present () {
    if [ -e ${PROJECT_DIR}/Dependencies/${SYSTEM}/libprotobuf.a ] &&
       [ -e ${PROJECT_DIR}/Dependencies/${SYSTEM}/libtensorflow.a ] &&
       [ -e ${PROJECT_DIR}/Dependencies/${SYSTEM}/libsnips_kaldi.dylib ] &&
       [ -e ${PROJECT_DIR}/Dependencies/${SYSTEM}/module.modulemap ] &&
       [ -e ${PROJECT_DIR}/Dependencies/${SYSTEM}/${LIBRARY_NAME_A} ] &&
       [ -e ${PROJECT_DIR}/Dependencies/${SYSTEM}/${HEADER_NAME_H} ]; then
        return 0
    fi

    return 1
}

case ${SYSTEM} in
    macos)
        echo "The platform macOS isn't yet supported."
        exit 1
    ;;
    ios)
        ARCHS_ARRAY=( ${ARCHS} )

        if [ ${SNIPS_USE_LOCAL_PLATFORM} == 1 ]; then
            install_local_core_platform && exit 0
        else
            if core_platform_is_present; then
                # TODO: Should check for version
                exit 0
            fi

            if ! install_local_core_platform; then
                install_remote_core_platform && exit 0
            fi
        fi
    ;;
    *)
        echo "This platform isn't supported."
        exit 1
    ;;
esac
