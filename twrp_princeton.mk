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

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

PRODUCT_DEVICE := princeton
PRODUCT_NAME := twrp_princeton
PRODUCT_BRAND := HONOR
PRODUCT_MODEL := PCT-AL10
PRODUCT_MANUFACTURER := HONOR

# Do not rely on LOCAL_PATH surviving the include chain from
# AndroidProducts.mk; define it here.
LOCAL_PATH := device/huawei/princeton

# Recovery-only build, no system image.
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=princeton \
    TARGET_DEVICE=princeton

#
# Files that go into the recovery ramdisk.
#
# AOSP 9's build-recoveryimage-target copies $(TARGET_ROOT_OUT) into the
# recovery root and then specifically copies $(TARGET_ROOT_OUT)/init.recovery.*.rc
# across. It does *not* read anything from the device tree's own
# recovery/root directory (TARGET_RECOVERY_DEVICE_DIRS was removed after
# 8.1), so files have to be listed here explicitly.
#
# init.recovery.princeton.rc is the one the recovery init imports
# (ro.hardware is kirin980, but TWRP imports init.recovery.${TARGET_DEVICE}.rc
# as well), and it is what starts teecd before keymaster needs it.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.princeton.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.princeton.rc \
    $(LOCAL_PATH)/recovery/root/etc/twrp/twrp.fstab:$(TARGET_COPY_OUT_RECOVERY)/root/etc/twrp/twrp.fstab
