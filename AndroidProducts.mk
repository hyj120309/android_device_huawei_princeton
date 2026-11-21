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
# Tells the build system which products this device tree provides.
#

TWRP_DEVICE_PATH := device/huawei/princeton

PRODUCT_MAKEFILES := \
    $(TWRP_DEVICE_PATH)/twrp_princeton.mk

COMMON_LUNCH_CHOICES := \
    twrp_princeton-eng
