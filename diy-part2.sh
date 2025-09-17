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

UPDATE_SCRIPT="${GITHUB_WORKSPACE:-$(pwd)}/scripts/update-golang.sh"
if [ -f "${UPDATE_SCRIPT}" ]; then
  echo "==> Running update-golang.sh (ensuring executable and running under openwrt root)"
  chmod +x "${UPDATE_SCRIPT}" || true
  if [ -d "${GITHUB_WORKSPACE:-$(pwd)}/openwrt" ]; then
    cd "${GITHUB_WORKSPACE:-$(pwd)}/openwrt" || true
  else
    echo "Note: openwrt directory not found under GITHUB_WORKSPACE, using current pwd: $(pwd)"
  fi
  bash "${UPDATE_SCRIPT}" || echo "Warning: update-golang.sh exited non-zero (continuing build)"
  cd "${GITHUB_WORKSPACE:-$(pwd)}" || true
else
  echo "==> No update-golang.sh found at ${UPDATE_SCRIPT}, skipping golang update"
fi
cd openwrt
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
