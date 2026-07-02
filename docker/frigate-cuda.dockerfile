ARG BASE_IMAGE="ghcr.io/blakeblackshear/frigate:0.17.1"
FROM ${BASE_IMAGE}
ARG PIP_BREAK_SYSTEM_PACKAGES=1

SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN --mount=type=bind,target=/resource/packages,from=packages <<EOF

apt-get -y install \
"/resource/packages/debs/cuda-8.0.61+cudnn-7.2.1-shared-libs_0.0-0.deb" \
"/resource/packages/debs/ffmpeg-7.0.3+nv-codec-headers-8.1.24.15-bin_0.0-0.deb"

# Switching back to the legacy "scale_npp" filter for better compatibility with old GPUs
sed -i 's/scale_cuda/scale_npp/g' "/opt/frigate/frigate/ffmpeg_presets.py"

# Uninstalling the existing onnx/onnxrutime first
pip3 uninstall --yes onnx onnxruntime

# Installing our custom-built version of onnx/onnxruntime
pip3 install \
/resource/packages/wheels/onnx-1.6.0-cp311-cp311-linux_x86_64.whl \
/resource/packages/wheels/onnxruntime_gpu-1.1.2-cp311-cp311-linux_x86_64.whl

EOF

# This environment variable is used by frigate to locate binaries of the
# default ffmpeg installation at "/usr/lib/ffmpeg/{DEFAULT_FFMPEG_VERSION}/bin".
# Our custom-built ffmpeg is set up accordingly, and this value is updated to
# tell frigate to invoke the desired version by default.
ENV DEFAULT_FFMPEG_VERSION="7.0.3"
ENV INCLUDED_FFMPEG_VERSIONS="7.0.3:${INCLUDED_FFMPEG_VERSIONS}"

