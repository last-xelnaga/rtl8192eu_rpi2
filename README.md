# rtl8192eu wifi driver for the Raspberry Pi 2


INTRO:
This manual was created mostly for myself, since i've
spent time once and do not want to waste it once again.
I will be glad if it will be useful for someone else.

Wi-Fi USB dongle D-Link DWA-131 E1 rev. (2001:3319) is
quite cheap and powerful wifi antenna but nowadays it
does not have an official linux support anymore from
D-Link/Realtek vendor. The latest driver 4.3.1.1_11320
was released in October 2014 and was able to support
linux kernels up to 3.10 (LTS). After that we have not
seen any new release from vendor, so it seems that we
have to do it without their help.

I've never tried this peace of hardware with linux
desktop or android based device, so i have no idea will
it work there or not (in theory it should but who knows).
My goal was is to use it with Raspberry Pi2 device and
Arch (preferably) linux.


FILES:
1.	several patches for the 4.3.1.1_11320 driver to make
	it compilable for RPi2
2.	config.gz is a kernel configuration file from my RPi2.
	could be used as a starting point for the kernel
	compilation procedure
3.	build.sh is a bash script that will do the job.


WORKFLOW:
1.	just store all files in one directory and execute
		./build.sh
2.	script will try to fetch cross-compilation tools.
	you can use your own tools (just put them in tools
	directory) and update script with a correct prefix
	for the cross-compiler binaries
3.	it's time for kernel. script will fetch kernel source
	and will compile it. once again, it's better to use
	your own kernel, otherwise your new wifi module will
	not work...
4.	script will download a zip archive with an official
	driver, extract, patch and compile.
5.	as a result there will be a module 8192eu.ko file in
	workbench/wifi directory


PITFALLS:
1.	copy new module to your RPi2 and execute as root
		depmod -a
2.	lsusb should show your wifi dongle as 2001:3319.
	only this PID:VID combination will kick the 8192eu
	module off.
		lsusb | grep D-Link
3.	before wifi connection setup try to check the module
	status with lsmod. it should be in the list of the
	loaded kernel modules.
		lsmod | grep 8192
4.	in case of wpa_supplicant usage, please specify linux
	wireless driver (wext) implicitly.
		wpa_supplicant -Dwext -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

