#!/bin/sh

# Build and install VPP
#git clone https://github.com/FDio/vpp.git
#cd vpp
#git checkout stable/2210

# Apply VPP patches 
#git am ../patches/vpp/*.patch

#make install-dep
#make install-ext-deps
#make build-release
#cp -r build-root/install-vpp-native/vpp /usr/local/  #VPP_HOME path

# Build UPG‑VPP for bare‐metal UPF
git clone https://github.com/travelping/upg-vpp.git
cd upg-vpp

# Apply UPG-VPP patches
git am ../patches/upg-vpp/*.patch

mkdir build
cd build 
cmake -DVPP_HOME=/usr/local/ ..  #adjust VPP_HOME accordingly
make
cp upf_plugin.so /usr/local/lib/x86_64-linux-gnu/vpp_plugins/ #vpp install
