#!/bin/sh

# Some general variables
PHONE="x3pro"
ARCH="arm64"
SUBARCH="arm64"
DEFCONFIG=nogravity_defconfig
COMPILER=clang
LINKER="lld"
COMPILERDIR="/media/pierre/Expension/Android/PocoX3Pro/Kernels/Proton-Clang"

curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

# Cleanup output
rm -rf out/outputs/${PHONE}/*

# Export shits
export KBUILD_BUILD_USER=Pierre2324
export KBUILD_BUILD_HOST=G7-7588

# Speed up build process
MAKE="./makeparallel"

# Basic build function
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

Build () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD_LIBRARY_PATH=${COMPILERDIR}/lib \
Image.gz-dtb dtbo.img
}

Build_lld () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD=ld.${LINKER} \
AR=llvm-ar \
NM=llvm-nm \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
STRIP=llvm-strip \
ld-name=${LINKER} \
KBUILD_COMPILER_STRING="Proton-Clang" \
Image.gz-dtb dtbo.img
}

miui_fix_dimens() {
    sed -i 's/<70>/<695>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-36-02-0a-lcd-dsc-vid.dtsi
    sed -i 's/<154>/<1546>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-36-02-0a-lcd-dsc-vid.dtsi
    sed -i 's/<70>/<695>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-42-02-0b-lcd-dsc-vid.dtsi
    sed -i 's/<154>/<1546>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-42-02-0b-lcd-dsc-vid.dtsi
}
restore_dimens() {
    sed -i 's/<695>/<70>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-36-02-0a-lcd-dsc-vid.dtsi
    sed -i 's/<1546>/<154>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-36-02-0a-lcd-dsc-vid.dtsi
    sed -i 's/<695>/<70>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-42-02-0b-lcd-dsc-vid.dtsi
    sed -i 's/<1546>/<154>/g' arch/arm64/boot/dts/qcom/dsi-panel-j20s-42-02-0b-lcd-dsc-vid.dtsi
}

# Make defconfig

make O=out ARCH=${ARCH} ${DEFCONFIG}
if [ $? -ne 0 ]
then
    echo "Build failed"
else
    echo "Made ${DEFCONFIG}"
fi

# Build starts here
if [ -z ${LINKER} ]
then
    Build
else
    Build_lld
fi

if [ $? -ne 0 ]
then
    echo "Build failed"
else
    echo "Build succesful"
    mkdir out/outputs
    mkdir out/outputs/${PHONE}
    find out/arch/arm64/boot/dts/qcom/ -name '*.dtb' -exec cat {} + >out/outputs/${PHONE}/dtb
    cp out/arch/arm64/boot/dtbo.img out/outputs/${PHONE}/dtbo.img
    cp out/arch/arm64/boot/Image.gz out/outputs/${PHONE}/Image.gz
    #MIUI dtbo
    rm out/outputs/dtbo-miui.img
    miui_fix_dimens
    echo | Build_lld
    if [ $? -ne 0 ]
    then
        rm out/outputs/dtbo-miui.img
    else
        cp out/arch/arm64/boot/dtbo.img out/outputs/dtbo-miui.img
    fi
    restore_dimens
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"