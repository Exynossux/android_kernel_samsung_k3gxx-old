#!bin/bash
clear

LANG=C

# location
KERNELDIR=$(readlink -f .);
RAMDISK_TMP=ramdisk_exynos5422_tmp
RAMDISK_DIR=ramdisk_exynos5422
DEFCONFIG=exynos5422-k3g_00_defconfig

CLEANUP()
{
	# begin by ensuring the required directory structure is complete, and empty
	echo "Initialising................."

	echo "Cleaning READY dir......."
	sleep 1;
	rm -rf "$KERNELDIR"/READY/boot
	rm -rf "$KERNELDIR"/READY/*.img
	rm -rf "$KERNELDIR"/READY/*.zip
	rm -rf "$KERNELDIR"/READY/*.sh
	rm -f "$KERNELDIR"/.config
	#### Cleanup bootimg_tools now #####
	echo "Cleaning bootimg_tools from unneeded data..."
	sleep 1;
	echo "Deleting kernel zImage named 'kernel' in bootimg_tools dir....."
	rm -f "$KERNELDIR"/bootimg_tools/boot_g900h/kernel
	sleep 1;
	echo "Deleting all files from ramdisk dir in bootimg_tools if it exists"
	if [ ! -d "$KERNELDIR"/bootimg_tools/boot_g900h/ramdisk ]; then
		mkdir -p "$KERNELDIR"/bootimg_tools/boot_g900h/ramdisk 
		chmod 777 "$KERNELDIR"/bootimg_tools/boot_g900h/ramdisk
	else
		rm -rf "$KERNELDIR"/bootimg_tools/boot_g900h/ramdisk/*
	fi;
	sleep 1;
	echo "Deleted all files from ramdisk dir in bootimg_tools";

	
	mkdir -p "$KERNELDIR"/READY/
	
	echo "Clean all files from temporary"
	if [ ! -d ../"$RAMDISK_TMP" ]; then
		mkdir ../"$RAMDISK_TMP"
		chown root:root ../"$RAMDISK_TMP"
		chmod 777 ../"$RAMDISK_TMP"
	else
		rm -rf ../"$RAMDISK_TMP"/*
	fi;

	echo "Make RELEASE directory if it doesn't exist and clean it if it exists"
	if [ ! -d ../RELEASE ]; then
		mkdir ../RELEASE
	else
		rm -rf ../RELEASE/*
	fi;


	# force regeneration of .dtb and zImage files for every compile
	rm -f arch/arm/boot/*.dtb
	rm -f arch/arm/boot/*.cmd
	rm -f arch/arm/boot/zImage
	rm -f arch/arm/boot/zImage-dtb
	rm -f arch/arm/boot/Image

}


BUILD_NOW()
{
	if [ ! -f "$KERNELDIR"/.config ]; then
		echo "Copying arch/arm/configs/$DEFCONFIG to .config"
		cp arch/arm/configs/"$DEFCONFIG" .config
	else
		rm -f "$KERNELDIR"/.config
		echo "Copying arch/arm/configs/$DEFCONFIG to .config"
		sleep 1;
		cp arch/arm/configs/"$DEFCONFIG" .config
	fi;

	# we don't build modules, so no need to delete them
	########

	### CPU thread usage
	# Idea by savoca
	NR_CPUS=$(grep -c ^processor /proc/cpuinfo)

	if [ "$NR_CPUS" -le "2" ]; then
		NR_CPUS=4;
		echo "Building kernel with 4 CPU threads";
	else
		echo "Building kernel with $NR_CPUS CPU threads";
	fi;

	# build zImage
	time make ARCH=arm CROSS_COMPILE=android-toolchain/bin/arm-eabi- zImage-dtb -j ${NR_CPUS}

	stat "$KERNELDIR"/arch/arm/boot/zImage || exit 1;

	# copy all ramdisk files to ramdisk temp dir.
	cp -a ../"$RAMDISK_DIR"/* ../"$RAMDISK_TMP"/

	# remove empty directory placeholders from tmp-initramfs
	for i in $(find ../"$RAMDISK_TMP"/ -name EMPTY_DIRECTORY); do
		rm -f "$i";
	done;

	if [ -e "$KERNELDIR"/arch/arm/boot/zImage ]; then
		cp arch/arm/boot/zImage bootimg_tools/boot_g900h/kernel
		cp .config READY/view_only_config

		# copy all ramdisk files to ramdisk temp dir.
		cp -a ../"$RAMDISK_TMP"/* bootimg_tools/boot_g900h/ramdisk/
		
		### Now I have ramdisk and kernel (zImage) and dtb dt.img in bootimg_tools
		### Also I have img_info which is kept every recompile for parsing mkbootimg parameters
		
		# Build boot.img and move it to READY dir
		echo "Move boot.img to READY/boot.img"
		cd bootimg_tools
		./mkboot boot_g900h ../READY/boot.img
		# Make flashable zip
		cd ../READY
		zip -r Kernel-g900h.zip * >/dev/null
		mv Kernel-g900h.zip ../../RELEASE/
	else
		# with red-color
		echo -e "\e[1;31mKernel STUCK in BUILD! no zImage exist\e[m"
	fi;

}

CLEAN_KERNEL()
{
	echo "Mrproper and clean running"
	sleep 1;
	make ARCH=arm mrproper;
	make clean;

	# clean ccache
	read -t 10 -p "clean ccache, 10sec timeout (y/n)?";
	if [ "$REPLY" == "y" ]; then
		ccache -C;
	fi;
}

echo "Initializing auto-build script......."
sleep 1;
CLEAN_KERNEL;
CLEANUP;
echo "Build now starting"
BUILD_NOW;
exit;