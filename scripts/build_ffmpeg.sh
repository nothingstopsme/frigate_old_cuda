#!/bin/bash

. "$(dirname "${BASH_SOURCE[0]}")/setup_buildenv.sh"

apt-get update
apt-get -y install libtool autoconf nasm

export PKG_CONFIG_LIBDIR="/opt/ffbuild/lib/pkgconfig:/opt/ffbuild/share/pkgconfig${PKG_CONFIG_LIBDIR:+:}${PKG_CONFIG_LIBDIR}"

FF_BUILD_PREFIX="/opt/ffbuild"
CUDA_PATH="/usr/local/cuda"

# Since ffmpeg build process will append "--ptx" to the final NVCC flags passed
# to nvcc compiler, only one GPU virtual architecture is allowed to be specified here;
# "compute_20" is given to have maximum compatibility
NVCC_FLAGS="-ccbin ${CXX} -gencode arch=compute_20,code=compute_20 -gencode arch=compute_20,code=sm_20 -O2"


echo "\nBuilding fdk-aac..."
FDK_AAC_SRC="/workdir/src/fdk-aac-2.0.3"
prepare_for_src_from_github "${FDK_AAC_SRC}" "https://github.com/mstorsjo/fdk-aac.git" "v2.0.3"
#prepare_for_src_from_tarball "$FDK_AAC_SRC" "https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v2.0.3.tar.gz"
pushd "${FDK_AAC_SRC}" > /dev/null
./autogen.sh
./configure --prefix="${FF_BUILD_PREFIX}" --enable-static=yes --enable-shared=no
make install
popd > /dev/null

echo "\nBuilding nv-codec-headers..."
NV_CODEC_HEADER_SRC="/workdir/src/nv-codec-headers-8.1.24.15"
prepare_for_src_from_github "${NV_CODEC_HEADER_SRC}" "https://github.com/FFmpeg/nv-codec-headers.git" "n8.1.24.15"
#prepare_for_src_from_tarball "$NV_CODEC_HEADER_SRC" "https://github.com/FFmpeg/nv-codec-headers/archive/refs/tags/n8.1.24.15.tar.gz"
pushd "${NV_CODEC_HEADER_SRC}" > /dev/null
make install PREFIX="${FF_BUILD_PREFIX}"
popd > /dev/null

echo "\nBuilding ffmpeg..."
FFMPEG_SRC="/workdir/src/ffmpeg-7.0.3"
prepare_for_src_from_github "${FFMPEG_SRC}" "https://github.com/FFmpeg/FFmpeg.git" "n7.0.3"
#prepare_for_src_from_tarball "$FFMPEG_SRC" "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n7.0.tar.gz"

FFMPEG_BASENAME="$(basename "${FFMPEG_SRC}")"
FF_DEB_PACKAGE_NAME="${FFMPEG_BASENAME}+$(basename "${NV_CODEC_HEADER_SRC}")-bin"
FF_DEB_PACKAGE_VERSION="0.0-0"
FF_DEB_PACKAGE_DIR="/workdir/install/${FF_DEB_PACKAGE_NAME}_${FF_DEB_PACKAGE_VERSION}"
FF_INSTALL_PREFIX="${FF_DEB_PACKAGE_DIR}/usr/local/${FFMPEG_BASENAME}"
pushd "${FFMPEG_SRC}" > /dev/null

# Even if fdk-aac is excluded, the use of cuda-nvcc alone, which is also a "nonfree" codec,
# makes the flag "--enable-nonfree" inevitable and hence the resulting binaries become non-free versions
FF_CONFIGURE="--enable-nonfree --enable-gpl --enable-version3 --disable-debug --enable-iconv --enable-libxml2 --enable-zlib --enable-libfreetype --enable-libfribidi --enable-gmp --enable-lzma --enable-fontconfig --enable-libvorbis --enable-opencl --enable-libpulse --enable-libxcb --enable-xlib --enable-amf --enable-libaom --enable-libaribb24 --enable-avisynth --enable-libdav1d --enable-libdavs2 --enable-frei0r --enable-libgme --enable-libass --enable-libbluray --enable-libjxl --enable-libmp3lame --enable-libopus --enable-mbedtls --enable-librist --enable-libtheora --enable-libvpx --enable-libwebp --enable-lv2 --enable-libvpl --enable-libopencore-amrnb --enable-libopencore-amrwb --enable-libopenh264 --enable-libopenjpeg --enable-libopenmpt --enable-librav1e --enable-librubberband --disable-schannel --enable-sdl2 --enable-libsoxr --enable-libsrt --enable-libsvtav1 --enable-libtwolame --enable-libuavs3d --enable-libdrm --enable-vaapi --enable-libvidstab --enable-vulkan --enable-libshaderc --enable-libplacebo --enable-libx264 --enable-libx265 --enable-libxavs2 --enable-libxvid --enable-libzimg --enable-libzvbi --disable-doc --disable-ffplay --enable-cuda-nvcc --enable-libnpp --enable-libfdk-aac"


#--enable-ffnvcodec --enable-cuda-llvm --disable-ptx-compression

FFBUILD_TARGET_FLAGS="--pkg-config=pkg-config --arch=x86_64 --target-os=linux"
FF_CFLAGS="-I/opt/ffbuild/include -I${CUDA_PATH}/include -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -DLIBTWOLAME_STATIC"
FF_CXXFLAGS="-I/opt/ffbuild/include -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection"
FF_LDFLAGS="-static-libgcc -static-libstdc++ -L /opt/ffbuild/lib -L /usr/lib/x86_64-linux-gnu -L /opt/ct-ng/x86_64-ffbuild-linux-gnu/sysroot/lib64 -L ${CUDA_PATH}/lib64 -O2 -pipe -fstack-protector-strong -fstack-clash-protection -Wl,-z,relro,-z,now -pthread -fPIC"
FF_LDEXEFLAGS="-pie"
FF_LIBS="-lgomp -ldl -lfinite-math -lm"

./configure --pkg-config-flags="--static" ${FFBUILD_TARGET_FLAGS} $FF_CONFIGURE \
  --extra-cflags="$FF_CFLAGS" --extra-cxxflags="$FF_CXXFLAGS" \
  --extra-ldflags="$FF_LDFLAGS" --extra-ldexeflags="$FF_LDEXEFLAGS" \
  --extra-libs="$FF_LIBS" \
  --prefix="${FF_INSTALL_PREFIX}" \
  --nvcc="${CUDA_PATH}/bin/nvcc" --nvccflags="${NVCC_FLAGS}"

make -j$(nproc)
make install

popd > /dev/null

echo "\nGenerating ffmpeg deb package..."
# Keeping "bin" folder only
rm -rf "${FF_INSTALL_PREFIX}/share" "${FF_INSTALL_PREFIX}/lib" "${FF_INSTALL_PREFIX}/include"

mkdir -p "${FF_DEB_PACKAGE_DIR}/DEBIAN"
cat << EOF > "${FF_DEB_PACKAGE_DIR}/DEBIAN/control"
Package: ${FF_DEB_PACKAGE_NAME}
Version: ${FF_DEB_PACKAGE_VERSION}
Section: base
Priority: optional
Architecture: amd64
Depends:
Maintainer: nobody <nobody@nobody.io>
Description: ${FFMPEG_BASENAME} binaries (ffmpeg + ffprobe) built
 1. against nv-codec-headers-8.1.24.15
 2. with support for nvidia GPUs of CC 2.0
EOF

cat << EOF > "${FF_DEB_PACKAGE_DIR}/DEBIAN/postinst"
#!/bin/bash

TARGET_PATH="/usr/lib/${FFMPEG_BASENAME/-//}"

if [[ -e "\${TARGET_PATH}" && ! -L "\${TARGET_PATH}" ]]; then
  mv "\${TARGET_PATH}" "\${TARGET_PATH}_backup"
fi

update-alternatives --install "\${TARGET_PATH}" ${FFMPEG_BASENAME} "/usr/local/${FFMPEG_BASENAME}" 100


if [[ -e "\${TARGET_PATH}_backup" ]]; then
  update-alternatives --install "\${TARGET_PATH}" ${FFMPEG_BASENAME} "\${TARGET_PATH}_backup" 0
fi
EOF

chmod 755 "${FF_DEB_PACKAGE_DIR}/DEBIAN/postinst"
dpkg-deb --build "${FF_DEB_PACKAGE_DIR}" "/workdir/packages/debs/${FF_DEB_PACKAGE_NAME}_${FF_DEB_PACKAGE_VERSION}.deb"
