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
# The build system picks device trees up through AndroidProducts.mk, so this
# file mainly exists because many users expect it and some TWRP branches
# call it from the top-level vendored setup. Keeping it empty of logic means
# there is no risk of it disagreeing with AndroidProducts.mk.
#

add_lunch_combo twrp_princeton-eng
