# Makefile for IMX95 with kernel build form source

#--------------
# Output folder
#--------------

# Folder for generated artifacts
result_folder ?= ./build

#---------------------
# Image specifications
#---------------------

# Specification of the partition layout of the image.raw
partition_layout = image.yaml
# Specification of the initrd.img
initrd_spec = initrd.yaml
# Specification of the root filesystem content and configuration
root_filesystem_spec = root.yaml

#-------------------------
# Additional configuration
#-------------------------

# Config script for root filesystem
config_root = ./config_root.sh



include beaglebone.mk