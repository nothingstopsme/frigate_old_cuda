ARG BASE_IMAGE="ghcr.io/blakeblackshear/frigate:0.17.1"
FROM ${BASE_IMAGE}

# Copying prebuilt codec libraries
COPY --from="ghcr.io/btbn/ffmpeg-builds/linux64-gpl:latest" /opt/ffbuild/ /opt/ffbuild/

# Copying standard libraries which the prebuilt codecs are compiled against
# to resolve "undefined references" during linking
COPY --from="ghcr.io/btbn/ffmpeg-builds/linux64-gpl:latest" \
/opt/ct-ng/x86_64-ffbuild-linux-gnu/sysroot/ /opt/ct-ng/x86_64-ffbuild-linux-gnu/sysroot/

SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN --mount=type=bind,target=/resource/patches,from=patches \
		--mount=type=bind,target=/resource/packages,from=packages <<EOF

ln -s /opt/ct-ng/x86_64-ffbuild-linux-gnu/sysroot/lib64 /opt/ct-ng/x86_64-ffbuild-linux-gnu/lib64

apt-get update

# Installing gcc-11/g++-11 as our host compiler
apt-get install -y gcc-11 g++-11 cmake patch git pkg-config

# Installing CUDA/CUDNN
apt-get install -y "/resource/packages/debs/cuda-8.0.61+cudnn-7.2.1-full_0.0-0.deb"

# Patching some of system and g++-11 headers which nvcc cannot work with
patch -d "/usr/include" -p1 < "/resource/patches/system_c++-11_user-include.diffpatch"

EOF

ENV CC="/usr/bin/gcc-11"
ENV CXX="/usr/bin/g++-11"
ENV AR="/usr/bin/gcc-ar-11"
ENV CFLAGS="-O2"
ENV CXXFLAGS="-O2"

RUN --mount=type=bind,target=/resource/src/finite-math,from=finite-math <<EOF

# Workaround: implementing some missing "finite" versions of math functions providied
# by older versions of GLIBC math libraries, but not by the newer version installed
# on this image
pushd /resource/src/finite-math > /dev/null
make INSTALL_PREFIX=/opt/ffbuild/lib/ all install
popd > /dev/null

EOF

WORKDIR /
CMD []
ENTRYPOINT ["/bin/bash"]


