#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
#echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default
rm -rf feeds/packages/net/adguardhome
rm -rf feeds/luci/applications/luci-app-adguardhome
rm -rf feeds/luci/applications/luci-app-homeproxy
git clone --depth 1 https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy
echo "==> 使用 kenzok8 的 adguardhome"
git clone --depth 1 https://github.com/kenzok8/openwrt-packages tmp-kenzo
mv tmp-kenzo/luci-app-adguardhome package/
mv tmp-kenzo/adguardhome package/
rm -rf tmp-kenzo
