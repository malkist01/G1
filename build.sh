#!/usr/bin/env bash
echo "Cloning dependencies"
mkdir -p "clang"
wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/4d2864f08ff2c290563fb903a5156e0504620bbe/clang-r563880c.tar.gz -O clang.tar.gz
tar -xf clang.tar.gz -C "clang"
rm -f clang.tar.gz
git clone https://github.com/sohamxda7/llvm-stable -b gcc64 --depth=1 gcc
git clone https://github.com/sohamxda7/llvm-stable -b gcc32  --depth=1 gcc32
git clone --depth=1 https://github.com/malkist01/AnyKernel2 AnyKernel
curl -LSs "https://raw.githubusercontent.com/malkist01/KernelSU-Next/legacy/kernel/setup.sh" | bash -s legacy
chmod +x ginkgo.sh && patch -p1 < seccomp.patch
chmod +x hooks.patch && patch -p1 < hooks.patch
chmod +x susfs-2.0.0.patch && patch -p1 -F 3 < susfs-2.0.0.patch
echo "Done"
ZIPNAME="Teletubies"
DEVICE="ginkgo"
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img
DTB=$(pwd)/out/arch/arm64/boot/dtb.img
TANGGAL=$(date +"%F-%S")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(${KERNEL_DIR}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export ARCH=arm64
export KBUILD_BUILD_HOST=malkist
export KBUILD_BUILD_USER="android"
# sticker plox
function sticker() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
        -d sticker="CAACAgEAAxkBAAEnKnJfZOFzBnwC3cPwiirjZdgTMBMLRAACugEAAkVfBy-aN927wS5blhsE" \
        -d chat_id=$chat_id
}
# Send info plox channel
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>• Teletubies Kernel •</b>%0ABuild started on <code>Circle CI</code>%0AFor device <b>Redmi Note 8</b> (ginkgo)%0Abranch <code>$(git rev-parse --abbrev-ref HEAD)</code>(master)%0AUnder commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0AUsing compiler: <code>${KBUILD_COMPILER_STRING}</code>%0AStarted on <code>$(date)</code>%0A<b>Build Status:</b>#Stable"
}
# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Redmi Note 8 (ginkgo)</b> | <b>$(${GCC}gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build throw an error(s)"
    exit 1
}
# Compile plox
function compile() {
    make O=out ARCH=arm64 vendor/ginkgo_defconfig
    make -j$(nproc --all) O=out \
                    ARCH=arm64 \
                    CC=clang \
                    LD=ld.lld \
                    AR=llvm-ar \
                    AS=llvm-as \
                    NM=llvm-nm \
                    OBJCOPY=llvm-objcopy \
                    OBJDUMP=llvm-objdump \
                    STRIP=llvm-strip \
                    CLANG_TRIPLE=aarch64-linux-gnu- \
                    CROSS_COMPILE=aarch64-linux-android- \
                    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                    Image.gz-dtb \
                    dtbo.img \
                    dtb.img 2>&1 | tee log.txt

    if ! [ -a "$IMAGE" "$DTBO" "$DTB" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel
    cp out/arch/arm64/boot/dtb.img AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 ${ZIPNAME}-${DEVICE}-${TANGGAL}.zip *
    cd ..
}
sticker
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push

