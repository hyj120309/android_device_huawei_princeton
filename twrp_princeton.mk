#
# Copyright (C) 2026 The android_device_huawei_princeton contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

#
# Product makefile for TWRP on the Honor V20 (princeton / PCT-AL10).
#
# Kirin 980, EMUI 9.1 (Android 9 / API 28), system-as-root.
#
# The product chain targets the twrp-11 (Android 11) tree. On Android 11
# target/product/embedded.mk no longer exists, and base.mk is the
# unsplit-product equivalent, so inherit that one; vendor/twrp pulls in the
# recovery GUI, the packages and the common properties.
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, vendor/twrp/config/common.mk)

PRODUCT_DEVICE := princeton
PRODUCT_NAME := twrp_princeton
PRODUCT_BRAND := HONOR
PRODUCT_MODEL := PCT-AL10
PRODUCT_MANUFACTURER := HONOR
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=princeton \
    TARGET_DEVICE=princeton

# Do not rely on LOCAL_PATH surviving the include chain from
# AndroidProducts.mk; define it here.
LOCAL_PATH := device/huawei/princeton

#
# Files that go into the recovery ramdisk.
#
# Only init.recovery.*.rc files survive the build's ramdisk cleanup, and
# TWRP's init.rc imports exactly /init.recovery.${ro.hardware}.rc. On this
# device ro.hardware is kirin980, so that is the name that counts; the same
# file is also installed under the device name in case ro.hardware turns
# out different on the running device. The rc starts teecd before keymaster
# needs it.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.princeton.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.kirin980.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.princeton.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.princeton.rc

# The fstab deliberately has no PRODUCT_COPY_FILES entry: BoardConfig.mk
# sets TARGET_RECOVERY_FSTAB, and build-recoveryimage-target copies that
# file to /system/etc/recovery.fstab itself. TWRP finds it through the
# ramdisk's /etc -> /system/etc symlink as /etc/recovery.fstab. Copying it
# to /etc/twrp/... instead (as this tree did originally) would not work:
# TWRP only looks for /etc/twrp.fstab and /etc/recovery.fstab, and a real
# /etc directory in the ramdisk would break the /etc symlink anyway.
