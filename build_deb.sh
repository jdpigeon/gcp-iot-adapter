#! /bin/bash
set -e

# script makes a debian package of iot adapter
# designed to be run from docker
echo "Building .deb..."

cp -pvr debian-pkg /tmp
cd /tmp/debian-pkg/
./make_package.sh
cp gcp-iot-adapter_${BUILD_VER}-1.deb /mnt/workspace
