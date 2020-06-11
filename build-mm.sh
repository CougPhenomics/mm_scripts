#!/usr/bin/env sh
set -e

# Script used to build MM from source (on Linux/Ubuntu)

# Dependencies (ubuntu / debian)
# sudo apt install build-essential default-jre default-jdk autoconf automake libtool pkg-config zlib1g-dev swig ant clojure libboost-all-dev libjogl2-java libgluegen2-rt-java
# also want -> sudo apt install libgphoto2-dev libusb-dev libdc1394-dev libhidapi-dev libfreeimageplus-dev libfreeimageplus-doc


ROOT_DIR=$(pwd)
IJ_DIR="$ROOT_DIR/Fiji.app"
MM_DIR="$ROOT_DIR/micro-manager"
THIRDPARTY_DIR="$ROOT_DIR/3rdpartypublic"
# BOOST_DIR="$THIRDPARTY_DIR/boost-linux-x86_64"
# BOOST_LIB_DIR="$BOOST_DIR/lib"
BOOST_LIB_DIR="/usr/lib/x86_64-linux-gnu"  #system boost lib location

# start with clean install each time
rm -rf $IJ_DIR $MM_DIR

# Install ImageJ/Fiji

if [ ! -f "fiji-linux64.zip" ]; then
    echo "Downloading Fiji."
    wget "https://downloads.imagej.net/fiji/latest/fiji-linux64.zip"
fi

if [ ! -e "$IJ_DIR" ]; then
    unzip "fiji-linux64.zip"
fi

IJ_JAR=`ls -1 "${IJ_DIR}"/jars/ij-1.5*.jar`

# Install dependencies (ideally everything would be managed by Maven...)

mkdir -p "$THIRDPARTY_DIR/classext"
if [ ! -f "$THIRDPARTY_DIR/classext/iconloader.jar" ]; then
    wget -P "$THIRDPARTY_DIR/classext" "https://valelab4.ucsf.edu/svn/3rdpartypublic/classext/iconloader.jar"
fi

if [ ! -f "$THIRDPARTY_DIR/classext/TSFProto.jar" ]; then
    wget -P "$THIRDPARTY_DIR/classext" "https://valelab4.ucsf.edu/svn/3rdpartypublic/classext/TSFProto.jar"
fi

if [ ! -f "$THIRDPARTY_DIR/classext/clooj.jar" ]; then
    wget -P "$THIRDPARTY_DIR/classext" "https://valelab4.ucsf.edu/svn/3rdpartypublic/classext/clooj.jar"
fi

# Boost shipped by Ubuntu is now to recent and does not work well with Micro-manager.
# So we install an older version (1.57).

# if [ ! -e "$BOOST_DIR" ]; then
# 	mkdir -p "$BOOST_DIR"
# 	cd "$BOOST_DIR"
#     wget "https://anaconda.org/anaconda/boost/1.65.0/download/linux-64/boost-1.65.0-py36_4.tar.bz2"
#     tar -jxvf "boost-1.65.0-py36_4.tar.bz2"
#     # rm "boost-1.67.0-py27_4.tar.bz2"
#     cd ../../
# fi

# Clone the git repository
if [ ! -e "$MM_DIR" ]; then
  git clone https://github.com/CougPhenomics/micro-manager.git
fi

cd "$MM_DIR"
if [ -d ".git" ]; then
  git checkout ubuntu
  VERSION_ID=$(git rev-parse --short HEAD)
elif [ -d ".svn" ]; then
  VERSION_ID="svn-"$(svn info --show-item=revision .)
else
  VERSION_ID=$(date +%F)
fi

# Launch the build process (it can take a while)

./autogen.sh
./configure --enable-imagej-plugin="$IJ_DIR" \
            --with-ij-jar="$IJ_JAR" \
            LDFLAGS=-L"$BOOST_LIB_DIR"
            # --with-boost="$BOOST_DIR" 

make fetchdeps
make --jobs=`nproc --all`

# Install Micro-Manager

make install
cp "$MM_DIR/bindist/any-platform/MMConfig_demo.cfg" "$IJ_DIR"

# Copy boost libraries to ImageJ folder
cp --no-dereference --recursive "${BOOST_LIB_DIR}" "${IJ_DIR}/"

cd ../

# Generate zip bundle for distribution and backup

mkdir -p "bundles/"
BUNDLE_NAME="$(date +"%Y.%m.%d.%H.%M").MicroManager-${VERSION_ID}.zip"
zip --symlinks --recurse-paths "bundles/$BUNDLE_NAME" "Fiji.app"
