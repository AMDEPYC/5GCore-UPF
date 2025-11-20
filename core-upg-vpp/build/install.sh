#!/bin/sh

apt install -y net-tools

# To install VPP-UPF on bare-metal / VM as network function
git clone https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-upf-vpp.git
cd oai-cn5g-upf-vpp
git checkout develop

# install VPP software dependancies (make install-dep) */
cd ./build/scripts
./build_vpp_upf -I -f

# Build UPF (release mode) (vpp binaries installed in /bin/*)
./build_vpp_upf -c -V

# Build UPF in debug mode 
cd oai-cn5g-upf-vpp/vpp
make build

# To patch VPP/UPF, modify (or) enhance 
# 'oai-cn5g-upf-vpp/build/scripts/build_helper.upf' to apply new patches
# add_Travelping_upf_plugin()
# apply_patches()
# check_install_vpp_upf_deps()
# install_dep()
# vpp_upf_init()
# remove_vpp_source()
