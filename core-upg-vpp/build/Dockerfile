FROM ubuntu:22.04

#ARG UPF_VERSION
ENV UPF_HOME=/5gupf
ENV UPF_INSTALL=/usr/local
ENV VPP_INSTALL=/5gupf/vpp/build-root/install-vpp-native/vpp/

RUN apt-get -qq update \
  && apt-get -qq install --no-install-recommends \
       build-essential \
       ca-certificates \
       libbsd-dev \
       libjansson-dev \
       libnuma-dev \
       libpcap-dev \
       libprotobuf-c-dev \
       libzstd1 \
       libzstd-dev \
       zstd \
       protobuf-c-compiler \
       autoconf \
       automake \
       flex \
       bison \
       vim-tiny \
       sudo \
       git \
       wget \
       libtool \
       make \
       python3-pip \
       python3-pyelftools \
       python3-scapy \
       python3-setuptools \
       xz-utils \
       pciutils \
       net-tools \
       iproute2 \
       pkgconf \
       libibverbs-dev \
       libmicrohttpd-dev \
       libcurl4-openssl-dev \
       libhyperscan-dev \
       unzip \
  && pip3 install \
       meson \
       ninja

# Copy patches to the container
COPY patches $UPF_HOME/patches
COPY scripts $UPF_HOME/scripts
#COPY config /config

RUN apt-get update && apt-get install -y git
ENV GIT_REPO=https://github.com/FDio/vpp.git
ENV GIT_TAG=stable/2210

RUN cd ${UPF_HOME} \
  && git clone ${GIT_REPO} \
  && cd vpp \
  && git checkout ${GIT_TAG}

# Apply DPDK patches (external packages)
RUN cd $UPF_HOME/vpp \
  && mkdir -p build/external/patches/dpdk_22.07 \
  && for patch in ${UPF_HOME}/patches/dpdk/*.patch; do \
        cp $patch build/external/patches/dpdk_22.07; \
     done

# Apply VPP patches
RUN cd $UPF_HOME/vpp \
  && for patch in ${UPF_HOME}/patches/vpp/*.patch; do \
        patch -p1 < $patch; \
     done

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y sudo

# Install all build essentials and required tools
RUN apt-get update && \
    apt-get install -y \
        libelf-dev \
        libnuma-dev \
        libpcap-dev \
        libssl-dev \
        dkms \
        debhelper \
        fakeroot \
        dpkg-dev \
        nasm \
        ninja-build \
        pkg-config \
        python3-venv \
        python3.10-venv \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        git \
        sudo \
        wget \
        cmake \
        curl \
        ca-certificates \
        gnupg \
        lsb-release \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    build-essential ca-certificates git sudo wget curl cmake \
    libelf-dev libnuma-dev libpcap-dev libssl-dev \
    dkms debhelper fakeroot dpkg-dev nasm ninja-build pkg-config \
    python3-venv python3.10-venv python3-pip python3-setuptools python3-wheel python3-yaml \
    libmnl-dev libyaml-dev libedit-dev libpng-dev \
    aspell aspell-en dictionaries-common \
    ccache clang llvm \
    libclang-dev libclang-cpp14-dev llvm-14-dev llvm-14-tools \
    && rm -rf /var/lib/apt/lists/*

# First run install-dep safely
RUN DEBIAN_FRONTEND=noninteractive \
    cd $UPF_HOME/vpp \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        dkms debhelper fakeroot dpkg-dev \
    && make install-dep \
    && make install-ext-deps

RUN cd $UPF_HOME/vpp \
  && make build-release

#RUN cp -r $UPF_HOME/vpp/build-root/install-vpp-native/vpp ${VPP_INSTALL}

# Apply UPG-VPP patches
RUN cd $UPF_HOME \
  && git clone https://github.com/travelping/upg-vpp.git \
  && cd upg-vpp \
  && git checkout tags/v1.13.1 \
  && for patch in ${UPF_HOME}/patches/upg-vpp/*.patch; do \
        patch -p1 < $patch; \
     done

#RUN cd $UPF_HOME \
#  && git clone https://github.com/travelping/upg-vpp.git \
#  && cd upg-vpp \
#  && git config user.email "builder@example.com" \
#  && git config user.name "Docker Builder" \
#  && git am ${UPF_HOME}/patches/upg-vpp/*.patch \
#  && [ -f upf/version.h ] || echo '#define UPG_VERSION "1.13.0"' > upf/version.h \
#  && export PATH=${VPP_INSTALL}/bin:$PATH \
#  && mkdir -p build \
#  && cd build \
#  && cmake -DVPP_HOME=${VPP_INSTALL} .. \
#  && make -j$(nproc) \
#  && cp upf_plugin.so ${VPP_INSTALL}/lib/x86_64-linux-gnu/vpp_plugins/

RUN cd $UPF_HOME/upg-vpp \
  && make version \
  && mkdir build \
  && cd build \
  && cmake -DVPP_HOME=${VPP_INSTALL} .. \
  && make \
  && cp upf_plugin.so ${VPP_INSTALL}/lib/x86_64-linux-gnu/vpp_plugins/

RUN cp -a $UPF_HOME/vpp/build-root/install-vpp-native/vpp/bin/. ${UPF_INSTALL}/bin/
RUN cp -r $UPF_HOME/vpp/build-root/install-vpp-native/vpp/lib/x86_64-linux-gnu ${UPF_INSTALL}/lib/
RUN sudo groupadd vpp \
  && sudo mkdir -p /run/vpp \
  && sudo chown root:vpp /run/vpp

RUN alias vim='vim.tiny'
ENV PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig
