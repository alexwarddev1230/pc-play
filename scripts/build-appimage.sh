BUILD_CONFIG="release"

fail()
{
	echo "$1" 1>&2
	exit 1
}

BUILD_ROOT=$PWD/build
SOURCE_ROOT=$PWD
BUILD_FOLDER=$BUILD_ROOT/build-$BUILD_CONFIG
DEPLOY_FOLDER=$BUILD_ROOT/deploy-$BUILD_CONFIG
INSTALLER_FOLDER=$BUILD_ROOT/installer-$BUILD_CONFIG
RAW_BUILD_DATA_FOLDER=$BUILD_ROOT/raw-build-data-$BUILD_CONFIG
VERSION=`cat $SOURCE_ROOT/app/version.txt`

command -v qmake >/dev/null 2>&1 || fail "Unable to find 'qmake' in your PATH!"
command -v linuxdeployqt >/dev/null 2>&1 || fail "Unable to find 'linuxdeployqt' in your PATH!"

echo Cleaning output directories
rm -rf $BUILD_FOLDER
rm -rf $DEPLOY_FOLDER
rm -rf $INSTALLER_FOLDER
rm -rf $RAW_BUILD_DATA_FOLDER
mkdir $BUILD_ROOT
mkdir $BUILD_FOLDER
mkdir $DEPLOY_FOLDER
mkdir $INSTALLER_FOLDER
mkdir $RAW_BUILD_DATA_FOLDER

echo Configuring the project
pushd $BUILD_FOLDER
# Building with Wayland support will cause linuxdeployqt to include libwayland-client.so in the AppImage.
# Since we always use the host implementation of EGL, this can cause libEGL_mesa.so to fail to load due
# to missing symbols from the host's version of libwayland-client.so that aren't present in the older
# version of libwayland-client.so from our AppImage build environment. When this happens, EGL fails to
# work even in X11. To avoid this, we will disable Wayland support for the AppImage.
#
# We disable DRM support because linuxdeployqt doesn't bundle the appropriate libraries for Qt EGLFS.
qmake $SOURCE_ROOT/moonlight-qt.pro CONFIG+=disable-wayland CONFIG+=disable-libdrm PREFIX=$DEPLOY_FOLDER/usr DEFINES+=APP_IMAGE || fail "Qmake failed!"
popd

echo Compiling Moonlight in $BUILD_CONFIG configuration
pushd $BUILD_FOLDER
make -j$(nproc) $(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]') || fail "Make failed!"
popd

echo Deploying to staging directory
pushd $BUILD_FOLDER
make install || fail "Make install failed!"
popd

echo Creating AppImage
pushd $INSTALLER_FOLDER
VERSION=$VERSION linuxdeployqt $DEPLOY_FOLDER/usr/share/applications/com.moonlight_stream.Moonlight.desktop -qmldir=$SOURCE_ROOT/app/gui -appimage || fail "linuxdeployqt failed!"
popd

echo Build successful

echo Extracting raw build data from the AppImage
pushd $RAW_BUILD_DATA_FOLDER
chmod +x $INSTALLER_FOLDER/*.AppImage || fail "Failed to make AppImage executable"
cp -R $INSTALLER_FOLDER/*.AppImage $RAW_BUILD_DATA_FOLDER
$RAW_BUILD_DATA_FOLDER/*.AppImage --appimage-extract || fail "AppImage extraction failed!"
tar -czvf linux_bin.tar.gz squashfs-root/

echo Archive complete
mv $RAW_BUILD_DATA_FOLDER/linux_bin.tar.gz $INSTALLER_FOLDER
popd

echo Extract successful