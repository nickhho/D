#!/bin/bash

# Build script for local testing
set -e

KERNEL_DIR="kernel"
CLANG_VERSION="r498229b"
JOBS=$(nproc --all)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting GKI 5.10 Kernel Build${NC}"

# Setup environment
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
export LLVM=1
export LLVM_IAS=1

# Clone kernel if not exists
if [ ! -d "$KERNEL_DIR" ]; then
    echo -e "${YELLOW}Cloning kernel source...${NC}"
    git clone --depth=1 https://github.com/ramabondanp/android_kernel_common-5.10 $KERNEL_DIR
fi

cd $KERNEL_DIR

# Clone KernelSU if not exists
if [ ! -d "KernelSU" ]; then
    echo -e "${YELLOW}Cloning KernelSU...${NC}"
    git clone --depth=1 https://github.com/RapliVx/KernelSU
fi

# Download Clang if not exists
if [ ! -d "../clang" ]; then
    echo -e "${YELLOW}Downloading Clang...${NC}"
    cd ..
    wget -O clang.zip https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-$CLANG_VERSION.tar.gz
    mkdir -p clang
    tar -xzf clang.zip -C clang
    export PATH=$(pwd)/clang/bin:$PATH
    cd $KERNEL_DIR
fi

# Apply KernelSU
if [ -f "KernelSU/setup.sh" ]; then
    bash KernelSU/setup.sh
fi

# Configure
echo -e "${YELLOW}Configuring kernel...${NC}"
make clean || true
make mrproper || true
make gki_defconfig

# Add KernelSU and HZ config
echo "CONFIG_KSU=y" >> .config
echo "CONFIG_KSU_SUSFS=y" >> .config
echo "CONFIG_HZ_300=y" >> .config
echo "CONFIG_HZ=300" >> .config

# Disable debug
echo "CONFIG_DEBUG_INFO=n" >> .config
echo "CONFIG_DEBUG_INFO_REDUCED=n" >> .config

make olddefconfig

# Build
echo -e "${GREEN}Building kernel with $JOBS jobs...${NC}"
make -j$JOBS

# Check success
if [ -f "arch/arm64/boot/Image" ]; then
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "Kernel image: $(pwd)/arch/arm64/boot/Image"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

cd ..
