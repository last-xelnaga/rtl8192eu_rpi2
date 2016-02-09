#! /bin/bash

function info()
{
	echo -e "\e[00;35m$*\e[00m" >&2 #purple
}

function error()
{
	echo -e "\e[00;31m$*\e[00m" >&2 #green
 	exit 1
}

# patch to all scripts and patches
SCRIPT_ROOT=$(pwd)

# workbench setup
WORKBENCH=$SCRIPT_ROOT/workbench
WORKBENCH_TOOLS=$WORKBENCH/tools
WORKBENCH_LINUX=$WORKBENCH/linux
WORKBENCH_WIFI=$WORKBENCH/wifi

# wifi module specific names
WIFI_BUNDLE_ZIP_FILE_NAME=20140812_DWA131_Linux_driver_v4.3.1.1.zip
WIFI_SOURCE_FILE_NAME=20140812_rtl8192EU_linux_v4.3.1.1_11320

# toolchain specific params
CROSS_GCC=$WORKBENCH_TOOLS/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-


# get cross-compile tools
if [ ! -d $WORKBENCH_TOOLS ]; then
	mkdir -p $WORKBENCH
	cd $WORKBENCH

	info "clone tools..."
	git clone https://github.com/raspberrypi/tools
	if [ "$?" -ne "0" ]; then
		error "failed to get tools"
	fi
else
	info "tools already in place, skipping..."
fi


# get linux source, configure and compile
if [ ! -d $WORKBENCH_LINUX ]; then
	mkdir -p $WORKBENCH
	cd $WORKBENCH

	info "clone kernel source..."
	git clone --depth=1 https://github.com/raspberrypi/linux
	if [ "$?" -ne "0" ]; then
		error "failed to get kernel source"
	fi

	info "prepare old config..."
	cp -a $SCRIPT_ROOT/config.gz $WORKBENCH_LINUX/config.gz
	cd $WORKBENCH_LINUX
	zcat config.gz > .config
	if [ "$?" -ne "0" ]; then
		info "failed to configure old kernel, go for new one..."
		make -j 12 ARCH=arm CROSS_COMPILE=$CROSS_GCC bcm2709_defconfig
		if [ "$?" -ne "0" ]; then
			error "failed to configure kernel"
		fi
	else
		make -j 12 ARCH=arm CROSS_COMPILE=$CROSS_GCC oldconfig
		if [ "$?" -ne "0" ]; then
			error "failed to configure kernel"
		fi
	fi
else
	info "kernel already in place, skipping..."
fi


# compile kernel if needed
info "compile kernel..."
cd $WORKBENCH_LINUX
make -j 12 ARCH=arm CROSS_COMPILE=$CROSS_GCC zImage modules dtbs
if [ "$?" -ne "0" ]; then
	error "failed to compile kernel"
fi


# get wifi source
if [ ! -d "$WORKBENCH_WIFI" ]; then
	mkdir -p $WORKBENCH_WIFI
	cd $WORKBENCH_WIFI

	info "download wifi module..."
	wget -c http://ftp.dlink.ru/pub/Wireless/DWA-131_E1A/Drivers/rev.E/Linux%20OS/4.3.1.1/$WIFI_BUNDLE_ZIP_FILE_NAME
	if [ "$?" -ne "0" ]; then
		error "failed to download wifi module source"
	fi

	info "unzip archive..."
	unzip $WIFI_BUNDLE_ZIP_FILE_NAME
	if [ "$?" -ne "0" ]; then
		error "failed to unzip $WIFI_BUNDLE_ZIP_FILE_NAME"
	fi

	info "untar source..."
	tar xzf $WIFI_SOURCE_FILE_NAME.tar.gz
	if [ "$?" -ne "0" ]; then
		error "failed to extract sorces from $WIFI_SOURCE_FILE_NAME.tar.gz"
	fi

	info "patch source..."
	cd $SCRIPT_ROOT
	for f in *.patch; do
		cp -a $SCRIPT_ROOT/$f $WORKBENCH_WIFI/$WIFI_SOURCE_FILE_NAME/$f
		cd $WORKBENCH_WIFI/$WIFI_SOURCE_FILE_NAME
		patch -p0 < $f
		if [ "$?" -ne "0" ]; then
			error "failed to apply patch $f"
		fi
	done
fi


# compile wifi module
info "compile module..."
cd $WORKBENCH_WIFI/$WIFI_SOURCE_FILE_NAME

make clean
make ARCH=arm CROSS_COMPILE=$CROSS_GCC USER_EXTRA_CFLAGS=-DCONFIG_LITTLE_ENDIAN KSRC=$WORKBENCH_LINUX KSRV=4.1.17 modules
if [ "$?" -ne "0" ]; then
	error "failed to compile wifi module"
fi


# strip the module and copy to workbench
make CROSS_COMPILE=$CROSS_GCC strip
cp -a 8192eu.ko $WORKBENCH_WIFI/8192eu.ko

