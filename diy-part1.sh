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

# ==> 清理 feeds 中的默认软件包定义，防止冲突
echo "==> Removing default packages from feeds to prevent conflicts..."
rm -rf feeds/luci/applications/luci-app-homeproxy
rm -rf feeds/packages/net/sing-box

# ==> 添加自定义软件包
echo "==> Adding custom packages..."

# 1. 添加 immortalwrt 的 HomeProxy (这是一个独立仓库，直接 clone 即可)
echo "Cloning luci-app-homeproxy..."
git clone --depth=1 https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy

# 2. 使用 sparse-checkout 添加 kenzok8 的 AdGuard Home 和 luci-app-adguardhome
echo "Cloning AdGuardHome packages from kenzok8..."
PKG_REPO_URL="https://github.com/kenzok8/openwrt-packages"
PKG_BRANCH="master"
# 需要拉取的软件包文件夹
PKG_DIRS="luci-app-adguardhome"

# 创建临时目录并进行 sparse checkout
git clone --depth 1 --no-checkout --filter=blob:none -b "$PKG_BRANCH" "$PKG_REPO_URL" kenzok8-packages
cd kenzok8-packages
git sparse-checkout init --cone
git sparse-checkout set $PKG_DIRS
git checkout "$PKG_BRANCH"
# 将拉取到的文件移动到 package 目录
mv -f $PKG_DIRS ../package/
cd ..
rm -rf kenzok8-packages

# 3. 使用 sparse-checkout 添加 immortalwrt 的最新版 sing-box
echo "Cloning latest sing-box from immortalwrt/packages..."
PKG_REPO_URL="https://github.com/immortalwrt/packages"
PKG_BRANCH="master"
PKG_DIRS="net/sing-box"

git clone --depth 1 --no-checkout --filter=blob:none -b "$PKG_BRANCH" "$PKG_REPO_URL" immortalwrt-packages
cd immortalwrt-packages
git sparse-checkout init --cone
git sparse-checkout set $PKG_DIRS
git checkout "$PKG_BRANCH"
mv -f $PKG_DIRS ../package/
cd ..
rm -rf immortalwrt-packages

echo "All custom packages added successfully."
