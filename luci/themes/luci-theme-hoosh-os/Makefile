#
# Copyright (C) 2020 Jo-Philipp Wich <jo@mein.io>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI modern theme
LUCI_DEPENDS:=+luci-base

PKG_LICENSE:=Apache-2.0

define Package/luci-theme-hoosh-os/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	uci -q delete luci.themes.hoosh-os
	uci commit luci
}
endef

include ../../luci.mk
