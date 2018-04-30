#! /bin/bash

#
# Build artoolkitX Camera Calibration utility for desktop platforms.
#
# Copyright 2018, Realmax, Inc.
# Copyright 2016-2017, DAQRI LLC.
#
# Author(s): Philip Lamb, Thorsten Bux, John Wolf, Dan Bell.
#

# Get our location.
OURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SDK_VERSION='1.0.0'
# If the tiny version number is 0, drop it.
SDK_VERSION_PRETTY=`echo -n "${SDK_VERSION}" | sed -E -e 's/([0-9]+\.[0-9]+)\.0/\1/'`
SDK_URL_DIR="https://github.com/artoolkitx/artoolkitx/releases/download/${SDK_VERSION_PRETTY}/"

VERSION=`sed -En -e 's/.*VERSION_STRING[[:space:]]+"([0-9]+\.[0-9]+(\.[0-9]+)*)".*/\1/p' ${OURDIR}/version.h`
# If the tiny version number is 0, drop it.
VERSION=`echo -n "${VERSION}" | sed -E -e 's/([0-9]+\.[0-9]+)\.0/\1/'`

function usage {
    echo "Usage: $(basename $0) [--debug] (macos | windows | linux | linux-raspbian)... "
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

# -e = exit on errors; -x = debug
set -e

# -x = debug
#set -x

# Parse parameters
while test $# -gt 0
do
    case "$1" in
        osx) BUILD_MACOS=1
            ;;
        macos) BUILD_MACOS=1
            ;;
        ios) BUILD_IOS=1
            ;;
        linux) BUILD_LINUX=1
            ;;
        linux-raspbian) BUILD_LINUX_RASPBIAN=1
            ;;
        windows) BUILD_WINDOWS=1
            ;;
        --debug) DEBUG=
            ;;
        --*) echo "bad option $1"
            usage
            ;;
        *) echo "bad argument $1"
            usage
            ;;
    esac
    shift
done

# Set OS-dependent variables.
OS=`uname -s`
ARCH=`uname -m`
TAR='/usr/bin/tar'
if [ "$OS" = "Linux" ]
then
    CPUS=`/usr/bin/nproc`
    TAR='/bin/tar'
    # Identify Linux OS. Sets useful variables: ID, ID_LIKE, VERSION, NAME, PRETTY_NAME.
    source /etc/os-release
    # Windows Subsystem for Linux identifies itself as 'Linux'. Additional test required.
    if grep -qE "(Microsoft|WSL)" /proc/version &> /dev/null ; then
        OS='Windows'
    fi
elif [ "$OS" = "Darwin" ]
then
    CPUS=`/usr/sbin/sysctl -n hw.ncpu`
elif [ "$OS" = "CYGWIN_NT-6.1" ]
then
    # bash on Cygwin.
    CPUS=`/usr/bin/nproc`
    OS='Windows'
elif [ "$OS" = "MINGW64_NT-10.0" ]
then
    # git-bash on Windows.
    CPUS=`/usr/bin/nproc`
    OS='Windows'
else
    CPUS=1
fi

function rawurlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo -n "${encoded}"
}

if [ "$OS" = "Darwin" ] ; then
# ======================================================================
#  Build platforms hosted by macOS
# ======================================================================

# macOS
if [ $BUILD_MACOS ] ; then
    
    # Fetch the ARX.framework from latest build into a location where Xcode will find it.
    SDK_FILENAME="artoolkitX for macOS v${SDK_VERSION_PRETTY}.dmg"
    curl -f -o "${SDK_FILENAME}" --location "${SDK_URL_DIR}$(rawurlencode "${SDK_FILENAME}")"
    hdiutil attach "${SDK_FILENAME}" -noautoopen -quiet -mountpoint "SDK"
    rm -rf depends/macOS/Frameworks/ARX.framework
    cp -af SDK/artoolkitX/SDK/Frameworks/ARX.framework depends/macOS/Frameworks
    hdiutil detach "SDK" -quiet -force
    
    # Make the version number available to Xcode.
    sed -E -i.bak "s/@VERSION@/${VERSION}/" macOS/user-config.xcconfig
    
    (cd macOS
    xcodebuild -target "artoolkitX Camera Calibration Utility" -configuration Release
    )
fi
# /BUILD_MACOS

# iOS
if [ $BUILD_IOS ] ; then
    
    # Fetch libARX from latest build into a location where Xcode will find it.
    SDK_FILENAME="artoolkitX for iOS v${SDK_VERSION_PRETTY}.dmg"
    curl -f -o "${SDK_FILENAME}" --location "${SDK_URL_DIR}$(rawurlencode "${SDK_FILENAME}")"
    hdiutil attach "${SDK_FILENAME}" -noautoopen -quiet -mountpoint "SDK"
    rm -rf depends/iOS/include/ARX/
    cp -af SDK/artoolkitX/SDK/include/ARX depends/iOS/include
    rm -f depends/iOS/lib/libARX.a
    cp -af SDK/artoolkitX/SDK/lib/libARX.a depends/iOS/lib
    hdiutil detach "SDK" -quiet -force
    
    # Make the version number available to Xcode.
    sed -E -i.bak "s/@VERSION@/${VERSION}/" iOS/user-config.xcconfig
    
    (cd iOS
    xcodebuild -target "artoolkitX Camera Calibration Utility" -configuration Release -destination generic/platform=iOS
    )
fi
# /BUILD_MACOS

fi
# /Darwin

if [ "$OS" = "Linux" ] ; then
# ======================================================================
#  Build platforms hosted by Linux
# ======================================================================

# Linux
if [ $BUILD_LINUX ] ; then
    #Before we can install the artoolkitx-dev package we need to install the -lib. As -dev depends on -lib
    SDK_FILENAME="artoolkitx-lib_${SDK_VERSION}_amd64.deb"
    curl -f -o "${SDK_FILENAME}" --location "${SDK_URL_DIR}$(rawurlencode "${SDK_FILENAME}")"
    sudo dpkg -i "${SDK_FILENAME}"

    # Fetch the artoolkitx-dev package and install it.
    SDK_FILENAME="artoolkitx-dev_${SDK_VERSION}_amd64.deb"
    curl -f -o "${SDK_FILENAME}" --location "${SDK_URL_DIR}$(rawurlencode "${SDK_FILENAME}")"
    sudo dpkg -i "${SDK_FILENAME}"

    (cd Linux
	mkdir -p build
	cd build
	cmake .. -DCMAKE_BUILD_TYPE=Release "-DVERSION=${VERSION}"
    make
	make install
    )

fi
# /BUILD_LINUX

# Linux
if [ $BUILD_LINUX_RASPBIAN ] ; then
    (cd Linux
	mkdir -p build-raspbian
	cd build-raspbian
	cmake .. -DCMAKE_BUILD_TYPE=Release -DARX_TARGET_PLATFORM_VARIANT="raspbian" -DVERSION="${VERSION}"
    make
	make install
    )

fi
# /BUILD_LINUX_RASPBIAN

fi
# /Linux

if [ "$OS" = "Windows" ] ; then
# ======================================================================
#  Build platforms hosted by Windows
# ======================================================================

# Windows
if [ $BUILD_WINDOWS ] ; then

    if [ ! -d "build-windows" ] ; then
        mkdir build-windows
    fi

    SDK_FILENAME="artoolkitX for Windows v${SDK_VERSION_PRETTY}.dmg"
    curl -f -o "${SDK_FILENAME}" --location "${SDK_URL_DIR}$(rawurlencode "${SDK_FILENAME}")"

    (cd Windows
    mkdir -p build
    cd build
    cmake.exe .. -DCMAKE_CONFIGURATION_TYPES=${DEBUG+Debug}${DEBUG-Release} "-GVisual Studio 15 2017 Win64"  -D"VERSION=${VERSION}"
    cmake.exe --build . --config ${DEBUG+Debug}${DEBUG-Release}  --target install
    )
fi
# /BUILD_WINDOWS

fi
# /Windows
