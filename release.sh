#!/bin/bash
VERSIONS=(7.1)
ARCHS=(
    "braswell"
#    "v1000"
)

set -e


# Download all necessary tarballs before calling into the docker containers.
echo "Downloading environment tarballs"
for ver in ${VERSIONS[@]}; do
    url_base="https://global.download.synology.com/download/ToolChain/toolkit/$ver"
    pushd toolkit_tarballs/
    if [ ! -f base_env-$ver.txz ]; then
        echo "$url_base/base_env-$ver.txz"
        wget -q --show-progress "$url_base/base/base_env-$ver.txz"
    fi
    for arch in ${ARCHS[@]}; do
        if [ ! -f ds.$arch-$ver.dev.txz ]; then
            wget -q --show-progress "$url_base/$arch/ds.$arch-$ver.dev.txz"
        fi
        if [ ! -f ds.$arch-$ver.env.txz ]; then
            wget -q --show-progress "$url_base/$arch/ds.$arch-$ver.env.txz"
        fi
    done
    popd
done

# Ensure that we are using an up to date docker image
docker build -t synobuild .

for ver in ${VERSIONS[@]}; do
    # Create release directory if needed
    mkdir -p target/$ver

    for arch in ${ARCHS[@]}; do
        echo "Building '$arch'"

        # Remove old artifact directory
        if [ -d artifacts/ ]; then
            rm -rf artifacts/
        fi
        
        mkdir -p toolkit_tarballs

        docker run \
            --rm \
            --privileged \
            --env PACKAGE_ARCH=$arch \
            --env DSM_VER=$ver \
            -v $(pwd)/artifacts:/result_spk \
            -v $(pwd)/toolkit_tarballs:/toolkit_tarballs \
            synobuild

        mv artifacts/WireGuard-*/* target/$ver/
    done
done

# Clean up artifact directory
if [ -d artifacts/ ]; then
    rm -rf artifacts/
fi

# Change permissions of the target directory to match the local user if called
# using sudo
if [ ! -z ${SUDO_USER+x} ]; then
    chown "$SUDO_USER:$SUDO_USER" -R target/
fi
