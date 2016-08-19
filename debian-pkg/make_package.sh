#! /bin/bash
set -e

# This script creates the directory structure for dpkg-deb --build

REL="${BUILD_VER}"
PKG_REVISION="1"
TARBALL="/mnt/workspace/amqp_pubsub.tar.gz" # location of fresh-built tarball
DEB_BASE_TARBALL="/tmp/debian-pkg/gcp-iot-adapter-debian-base.tar.gz" # contains DEBIAN dir
WORKDIR="/tmp/debian-pkg/gcp-iot-adapter_${REL}-${PKG_REVISION}"
BASEDIR="${WORKDIR}/opt/gcp-iot-adapter"
REL_DIR="${BASEDIR}/releases/${REL}"
INITSCRIPT="/tmp/debian-pkg/gcp-iot-adapter-initscript"

mkdir -p $WORKDIR
cd $WORKDIR

#tar xzf $DEB_BASE_TARBALL

# set version number in package files
cp -r ../DEBIAN .
sed -i "s/VER_NUMBER_HERE/${REL}/g" DEBIAN/control
sed -i "s/VER_NUMBER_HERE/${REL}/g" DEBIAN/postinst

# dirs to create in our fake "root filesystem"
mkdir -p opt/gcp-iot-adapter/
mkdir -p etc/init.d/
mkdir -p var/log/gcp-iot-adapter/

cd opt/gcp-iot-adapter
tar xzf $TARBALL

# move the default config file
# postinst will be repsonsible for copying it to /etc/ if needed
mv $REL_DIR/amqp_pubsub.conf $REL_DIR/amqp_pubsub.conf.dist

# make symlink to config file that will be in /etc
ln -f -s /etc/gcp-iot-adapter.conf $REL_DIR/amqp_pubsub.conf

# make symlink to log directory
ln -f -s /var/log/gcp-iot-adapter $BASEDIR/log

# copy init script into place
cp $INITSCRIPT $WORKDIR/etc/init.d/gcp-iot-adapter
# set version number in init script
sed -i "s/VER_NUMBER_HERE/${REL}/g" $WORKDIR/etc/init.d/gcp-iot-adapter

cd /tmp/debian-pkg
dpkg-deb --build gcp-iot-adapter_${REL}-${PKG_REVISION}

# postinst:
# - create system user
# - copy config file to /etc/ if one doesn't exist
# - chown /var/log/gcp-iot-adapter
