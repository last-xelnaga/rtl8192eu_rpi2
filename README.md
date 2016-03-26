## rtl8192eu wifi driver for the Raspberry Pi 2


### INTRO:
This manual was created mostly for myself, since i've
spent time once and do not want to waste it once again.
I will be glad if it will be useful for someone else.

Wi-Fi USB dongle **D-Link DWA-131 E1 rev.** (2001:3319) is
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


### FILES:
- several patches for the **4.3.1.1_11320** driver to make
  it compilable for RPi2
- **build.sh** is a bash script that will do the job.


### WORKFLOW:
- just store all files in one directory and execute

>	./build.sh

- script will try to fetch cross-compilation tools.
  you can use your own tools (just put them in tools
  directory) and update script with a correct prefix
  for the cross-compiler binaries
- it's time for kernel. script will fetch kernel source
  and will compile it. once again, it's better to use
  your own kernel, otherwise your new wifi module will
  not work...
- script will download a zip archive with an official
  driver, extract, patch and compile.
- as a result there will be a module 8192eu.ko file in
  workbench/wifi directory
- add a path of the mounted sdcard as a parameter and
  script will try to copy kernel and fresh module

>	./build.sh /dev/sde

  i use Arch distro, so script assumes that sdcard has
  two partitions: /boot - fat32 and /root - ext4. do not
  use this option if you are not sure about partitions in
  your favorite distro  


### PITFALLS:
- in case of cross-compilation your build tree has to have
  kernel headers with the SAME version as a kernel on your
  target 
- cross-compiler has to have the SAME version as a toolchain
  that was used for kernel compilation. that's why it's
  very convenient to compile kernel and additional modules
  at the same time.
- copy new module to your RPi2 and execute as root

>	depmod -a

- lsusb should show your wifi dongle as 2001:3319.
  only this PID:VID combination will kick the 8192eu
  module.

>	lsusb | grep D-Link

- before wifi connection setup try to check the module
  status with lsmod. it should be in the list of the
  loaded kernel modules.

>	lsmod | grep 8192

- in case of wpa_supplicant usage, please specify linux
  wireless driver (wext) implicitly.

>	wpa_supplicant -Dwext -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

