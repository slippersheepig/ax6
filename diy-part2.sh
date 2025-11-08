#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# 更新 sing-box：删除原有版本并克隆最新版
echo "==> 更新 sing-box 到最新版本"
rm -rf feeds/packages/net/sing-box
git clone --depth 1 https://github.com/immortalwrt/packages tmp-sing-box
cd tmp-sing-box
mv net/sing-box ../feeds/packages/net/
cd ..
rm -rf tmp-sing-box
# 更新 adguardhome：删除原有版本并克隆最新版
echo "==> 更新 adguardhome 到最新版本"
rm -rf feeds/packages/net/adguardhome
git clone --depth 1 https://github.com/kenzok8/openwrt-packages tmp-kenzo
mv tmp-kenzo/adguardhome feeds/packages/net/
rm -rf tmp-kenzo
# 修复 libnatpmp 的旧 CMake 版本声明
find package/feeds/packages/libnatpmp/CMakeLists.txt 2>/dev/null | while read -r file; do
    echo "Patching $file ..."
    sed -i '1s/.*/cmake_minimum_required(VERSION 3.5)/' "$file"
done
