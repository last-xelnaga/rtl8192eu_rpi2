#! /bin/bash

function info()
{
	echo -e "\e[00;32m$*\e[00m" >&2 #green
}

function warn()
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
WORKBENCH_MNT=$WORKBENCH/mnt

# wifi module specific names
WIFI_BUNDLE_ZIP_FILE_NAME=20140812_DWA131_Linux_driver_v4.3.1.1.zip
WIFI_SOURCE_FILE_NAME=20140812_rtl8192EU_linux_v4.3.1.1_11320
WIFI_MODULE_NAME=8192eu.ko

# kernel image name
KERNEL=kernel7

# toolchain specific params
CROSS_GCC=$WORKBENCH_TOOLS/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-

# sd card device name, for example /dev/sde
# will be initialized by first parameter.
#if empty, then installation will be skipped 
SDCARD_DEVICE=${1}

# get cross-compile tools
if [ ! -d $WORKBENCH_TOOLS ]; then
	mkdir -p $WORKBENCH
	cd $WORKBENCH

	info "clone tools..."
	git clone https://github.com/raspberrypi/tools
	if [ "$?" -ne "0" ]; then
		error "failed to get tools"
	fi

    info "checkout old but stable version..."
    cd $WORKBENCH_TOOLS
	git checkout 3a413ca2b23fd275e8ddcc34f3f9fc3a4dbc723f
	if [ "$?" -ne "0" ]; then
		error "failed to checkout"
	fi

else
	info "tools already in place, skipping..."
fi


# get linux source and configure
if [ ! -d $WORKBENCH_LINUX ]; then
	mkdir -p $WORKBENCH
	cd $WORKBENCH

	info "clone kernel source..."
	git clone https://github.com/raspberrypi/linux
	if [ "$?" -ne "0" ]; then
		error "failed to get kernel source"
	fi

	info "checkout old but stable version..."
	cd $WORKBENCH_LINUX
	git checkout f4b20d47d7df7927967fcd524324b145cfc9e2f9
	if [ "$?" -ne "0" ]; then
		error "failed to finish checkout, abort"
	fi

	info "failed to configure old kernel, go for new one..."
	make -j 12 ARCH=arm CROSS_COMPILE=$CROSS_GCC bcm2709_defconfig
	if [ "$?" -ne "0" ]; then
		error "failed to configure kernel"
	fi
else
	info "kernel already in place, skipping..."
fi


# get kernel version and flavor from .config file
cd $WORKBENCH_LINUX
KERNEL_VERSION=$(sed -n '3p' < .config | awk -F ' ' '{print $3}')
KERNEL_VERSION_FLAVOR=$(cat .config | grep LOCALVERSION= | cut -d "=" -f 2 | sed -e 's/^"//'  -e 's/"$//')
info "we have kernel $KERNEL_VERSION$KERNEL_VERSION_FLAVOR"


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

# configuration for the wifi module
EXTRA_CFLAGS=-DCONFIG_LITTLE_ENDIAN 
EXTRA_CFLAGS=$EXTRA_CFLAGS -DCONFIG_CONCURRENT_MODE
EXTRA_CFLAGS=$EXTRA_CFLAGS -DCONFIG_IOCTL_CFG80211
EXTRA_CFLAGS=$EXTRA_CFLAGS -DRTW_USE_CFG80211_STA_EVENT
EXTRA_CFLAGS=$EXTRA_CFLAGS -DCONFIG_P2P_IPS
EXTRA_CFLAGS=$EXTRA_CFLAGS -DCONFIG_QOS_OPTIMIZATION
EXTRA_CFLAGS=$EXTRA_CFLAGS -DCONFIG_USE_USB_BUFFER_ALLOC_TX
EXTRA_CFLAGS=$EXTRA_CFLAGS -DUSB_XMITBUF_ALIGN_SZ=1024
EXTRA_CFLAGS=$EXTRA_CFLAGS -DUSB_PACKET_OFFSET_SZ=0

make clean
make ARCH=arm CROSS_COMPILE=$CROSS_GCC USER_EXTRA_CFLAGS=$EXTRA_CFLAGS KSRC=$WORKBENCH_LINUX KSRV=$KERNEL_VERSION modules
if [ "$?" -ne "0" ]; then
	error "failed to compile wifi module"
fi


# strip the module and copy to workbench
make CROSS_COMPILE=$CROSS_GCC strip
cp -a $WIFI_MODULE_NAME $WORKBENCH_WIFI/$WIFI_MODULE_NAME
if [ "$?" -ne "0" ]; then
	warn "failed to copy wifi module"
fi


# post process. installation
if [ -n "${SDCARD_DEVICE}" ]; then
	if [ ! -d "$WORKBENCH_MNT/fat32" ]; then
		mkdir -p $WORKBENCH_MNT/fat32
		mkdir -p $WORKBENCH_MNT/ext4
	fi

	info "mount boot partition..."
	sudo mount $SDCARD_DEVICE1 $WORKBENCH_MNT/fat32
	if [ "$?" -ne "0" ]; then
		error "failed to mount $SDCARD_DEVICE1"
	fi

	info "mount root partition..."
	sudo mount $SDCARD_DEVICE2 $WORKBENCH_MNT/ext4
	if [ "$?" -ne "0" ]; then
		sudo umount $WORKBENCH_MNT/fat32
		error "failed to mount $SDCARD_DEVICE2"
	fi

	info "install linux kernel modules..."
	cd $WORKBENCH_LINUX
	sudo make ARCH=arm CROSS_COMPILE=$CROSS_GCC INSTALL_MOD_PATH=$WORKBENCH_MNT/ext4 modules_install
	if [ "$?" -ne "0" ]; then
		sudo umount $WORKBENCH_MNT/fat32
		sudo umount $WORKBENCH_MNT/ext4
		error "failed to install linux kernel modules"
	fi

	info "install wifi module..."
	cd $WORKBENCH_WIFI
	sudo cp -a $WIFI_MODULE_NAME $WORKBENCH_MNT/ext4/lib/modules/$KERNEL_VERSION$KERNEL_VERSION_FLAVOR/linux/net/wireless/
	if [ "$?" -ne "0" ]; then
		warn "failed to install wifi module"
	fi

	info "backup old kernel..."
	sudo cp -a $WORKBENCH_MNT/fat32/$KERNEL.img $WORKBENCH_MNT/fat32/$KERNEL-backup.img
	if [ "$?" -ne "0" ]; then
		warn "failed to backup old kernel"
	fi

	info "generate new one..."
	sudo $WORKBENCH_LINUX/scripts/mkknlimg $WORKBENCH_LINUX/arch/arm/boot/zImage $WORKBENCH_MNT/fat32/$KERNEL.img

	info "process overlay..."
	sudo cp -a $WORKBENCH_LINUX/arch/arm/boot/dts/*.dtb $WORKBENCH_MNT/fat32/
	sudo cp $WORKBENCH_LINUX/arch/arm/boot/dts/overlays/*.dtb* $WORKBENCH_MNT/fat32/overlays/
	sudo cp $WORKBENCH_LINUX/arch/arm/boot/dts/overlays/README $WORKBENCH_MNT/fat32/overlays/

	info "unmount all partitions..."
	sudo umount $WORKBENCH_MNT/fat32
	sudo umount $WORKBENCH_MNT/ext4
else
	warn "installation not needed. exit"
fi

