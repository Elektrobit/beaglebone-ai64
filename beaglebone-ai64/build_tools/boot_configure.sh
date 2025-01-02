#!/bin/sh

mkdir -p outdir/extlinux

cp opt/u-boot/bb-u-boot-beagleboneai64/microsd-extlinux.conf outdir/extlinux/

cp boot/vmlinuz* outdir/Image

cp -r boot/dtbs/*/*/overlays outdir/