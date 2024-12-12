# Makefile for IMX95 

# Arch for sysroot extraction
arch ?= aarch64

# default action
.PHONY: default
default: image

#--------------
# Result folder
#--------------

result_folder ?= ./build

#---------------------
# Select bash as shell
#---------------------

SHELL := /bin/bash

#---------------------
# Image specifications
#---------------------

# Specification of the partition layout of the image.raw
partition_layout ?= image.yaml
# Specification of the initrd.img
initrd_spec ?= initrd.yaml
# Specification of the root filesystem content and configuration
root_filesystem_spec ?= root.yaml

#-------------------------
# Additional configuration
#-------------------------

# Config script for root filesystem
config_root ?= config_root.sh

#--------------------
# Generated artifacts
#--------------------

# Folder for generated artifacts
kernel_result_folder ?= ./build

# Kernel image
kernel = $(kernel_result_folder)/vmlinuz
# Kernel modules
modules = $(kernel_result_folder)/lib
# Kernel config
kconfig = $(kernel_result_folder)/config
# Kernel source
kernel_source = kernel_src
# Path of the kernel sources
kernel_dir = $(kernel_source)/linux-imx
# Kernel make arguments
kernel_make_args = ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-

# The ifeqs allow overwriting the values
# if the makefile is used as include.

# Disc image
disc_image ?= $(result_folder)/image.raw

# Base root tarball
base_tarball ?= $(result_folder)/root.tar

# Configured root tarball
root_tarball ?= $(result_folder)/root.config.tar

# Generated initrd.img
initrd_img ?= $(result_folder)/initrd.img

# Sysroot tarball
sysroot_tarball ?= $(result_folder)/root_sysroot.tar

# Embdgen is used to build the SD card image.
$(disc_image): $(initrd_img) $(root_tarball) $(partition_layout)
	@echo "Build image..."
	mkdir -p $(result_folder)
	set -o pipefail && embdgen -o ./$(disc_image) $(partition_layout) 2>&1 | tee $(disc_image).log


# The root generator is used to build the base root filesystem tarball.
# root_filesystem_spec: specification of the root filesystem packages.
#
# This fist step only installs the specified packages. User configuration
# is done as a second step, because the build of this tarball is quite 
# time consuming and configuration is fast. This is an optimization for 
# the image development process.
$(base_tarball): $(root_filesystem_spec) kernel_imx95_build
	@echo "Build root.tar..."
	mkdir -p $(result_folder)
	set -o pipefail && root_generator --no-config $(root_filesystem_spec) $(result_folder) 2>&1 | tee $(base_tarball).log

# The root configurator is used to run the user configuration scripts
# as a separate step in the build process.
# base_tarball: tarball which is configured
# config_root: the used configuration script
$(root_tarball): $(base_tarball) $(config_root)
	@echo "Configuring ${base_tarball} as ${root_tarball}..."
	mkdir -p $(result_folder)
	set -o pipefail && root_configurator $(root_filesystem_spec) $(base_tarball) $(root_tarball) 2>&1 | tee $(root_tarball).log

# The initrd image is build using the initrd generator.
# initrd_spec: specification of the initrd image.
$(initrd_img): $(initrd_spec)
	@echo "Build initrd.img..."
	mkdir -p $(result_folder)
	set -o pipefail && initrd_generator $(initrd_spec) $(result_folder) 2>&1 | tee $(initrd_img).log

# The root generator is used to build a sysroot variant of the root filesystem.
# root_filesystem_spec: specification of the root filesystem
#
# --no-config means that the configuration step is skipped
$(sysroot_tarball): $(root_filesystem_spec)
	@echo "Build sysroot.tar..."
	mkdir -p $(result_folder)
	set -o pipefail && root_generator --sysroot --no-config $(root_filesystem_spec) $(result_folder) 2>&1 | tee $(sysroot_tarball).log

#--------------------------------------
# Open a shell for manual configuration
#--------------------------------------

# Helper targets to manually inspect and adapt the different tarballs.

.PHONY: edit_base
edit_base:
	@echo "Extacting base root tarball..."
	mkdir -p $(result_folder)/root
	fakeroot -s $(result_folder)/fakeedit -- tar xf $(base_tarball) -C $(result_folder)/root
	@echo "Open edit shell..."
	cd $(result_folder)/root && fakeroot -i ../fakeedit -s ../fakeedit
	@echo "Re-packing root tarball..."
	rm -f $(base_tarball).old
	mv $(base_tarball) $(base_tarball).old
	cd $(result_folder)/root && fakeroot -i ../fakeedit -s ../fakeedit -- tar cf ../../$(base_tarball) .
	rm -rf $(result_folder)/root

.PHONY: edit_root
edit_root:
	@echo "Extacting base root tarball..."
	mkdir -p $(result_folder)/root
	fakeroot -s $(result_folder)/fakedit -- tar xf $(root_tarball) -C $(result_folder)/root
	@echo "Open edit shell..."
	cd $(result_folder)/root && fakeroot -i ../fakedit -s ../fakeedit
	@echo "Re-packing root tarball..."
	rm -f $(root_tarball).old
	mv $(root_tarball) $(root_tarball).old
	cd $(result_folder)/root && fakeroot -i ../fakedit -s ../fakedit -- tar cf ../../$(root_tarball) .
	rm -rf $(result_folder)/root

.PHONY: kernel_imx95_build 
kernel_imx95_build:
	@echo "Get kernel sources..."
	mkdir -p $(kernel_source)
#   Clone kernel source from linux-imx that supports imx95
	cd $(kernel_source) && git clone --depth=1 "https://github.com/nxp-imx/linux-imx" -b "lf-6.6.23-2.0.0" || true
	cd $(kernel_dir) && chmod +x scripts/*
	cd $(kernel_dir) && $(MAKE) $(kernel_make_args) -j 16 imx_v8_defconfig
#   Image Build
	@echo "Build kernel binary..."
	mkdir -p $(result_folder)
	cd $(kernel_dir) && $(MAKE) $(kernel_make_args) -j 16 Image
	cp $(kernel_dir)/arch/arm64/boot/Image $(kernel)
	@echo "Results were written to $(kernel)"
#   modules Build
	mkdir -p $(result_folder)
	@echo "Build kernel modules..."
	cd $(kernel_dir) && $(MAKE) $(kernel_make_args) -j 16 modules
	cd $(kernel_dir) && INSTALL_MOD_PATH=../../$(result_folder) $(MAKE) $(kernel_make_args) modules_install
	@echo "Results were written to $(kernel)"
#   Dtbs compile
	mkdir -p $(result_folder)/dtbs
	@echo "Build dtbs .."
	cd $(kernel_dir) && $(MAKE) $(kernel_make_args) -j 16 dtbs
	cp $(kernel_dir)/arch/arm64/boot/dts/freescale/imx95-19x19-verdin-lt8912.dtb  $(result_folder)/dtbs
	@echo "Results were written to $(kernel)/dtbs"
	cd -
#--------------------------------
# Default make targets for images
#--------------------------------

# build of the disc image
.PHONY: image
image: $(disc_image)

# build of the root tarball(s)
.PHONY: root
root: $(base_tarball)

# build of the initrd.img(s)
.PHONY: initrd
initrd: $(initrd_img)

# config the root tarball
.PHONY: config
config: $(root_tarball)

# build the sysroot tarball
.PHONY: sysroot
sysroot: $(sysroot_tarball)

# install the sysroot tarball
.PHONY: sysroot_install
sysroot_install: $(sysroot_tarball)
	rm -rf /workspace/sysroot_$(arch)/*
	cp $(result_folder)/$(sysroot_tarball) /workspace/sysroot_$(arch)/
	cd /workspace/sysroot_$(arch)/ && tar xf $(sysroot_tarball)

# clean - delete the generated artifacts
.PHONY: clean
clean:
	rm -rf $(result_folder)