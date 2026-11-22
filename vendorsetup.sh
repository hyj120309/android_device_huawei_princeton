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
# Registers this device with lunch.
#
# The build system picks device trees up through AndroidProducts.mk, whose
# COMMON_LUNCH_CHOICES is the supported way to register products. In
# Android 9 this file used add_lunch_combo; that helper is gone in
# Android 11 (build/envsetup.sh prints an "obsolete" warning for it), so
# the file now carries no logic at all. It only stays because some flows
# source device vendorsetup.sh files and a missing file would be surprising.
#
