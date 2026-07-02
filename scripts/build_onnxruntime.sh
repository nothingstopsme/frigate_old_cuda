#!/bin/bash

SCRIPT_FOLDER="$(dirname "${BASH_SOURCE[0]}")"

. "${SCRIPT_FOLDER}/setup_buildenv.sh"

apt-get update
apt-get install -y python3-dev python-is-python3

# Enabling the locale "en_US.UTF-8", which will be used during testing
sed -i 's/# en_US.UTF-8 UTF-8/  en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# Removing existing onnx/onnxruntime packages first,
# so that they do not interfere with testing
pip3 uninstall --yes --break-system-packages onnx onnxruntime

# pytest is required during testing
pip3 install --break-system-packages pytest

mkdir -p "/workdir/packages/wheels"

echo "\nDownloading onnxruntime source"
ONNXRUNTIME_SRC="/workdir/src/onnxruntime-1.1.2"
prepare_for_src_from_github "${ONNXRUNTIME_SRC}" "https://github.com/Microsoft/onnxruntime.git" "v1.1.2"


pushd "${ONNXRUNTIME_SRC}" > /dev/null
# Retrieving submodules except for:
# 1. cub: The version from CUDA installation is used instead
# 2. grpc: Cloning this module will trigger user interaction and halt this script;
# skipping it since it is not used under our build configuration
git -c submodule."cmake/external/cub".update=none \
  -c submodule."cmake/external/grpc".update=none \
  submodule update --init --recursive



echo "\nBuilding protobuf compiler"
# Building the version protobuf checked out along onnxruntime
PROTOBUF_SRC="${ONNXRUNTIME_SRC}/cmake/external/protobuf"

pushd "${PROTOBUF_SRC}" > /dev/null
rm -rf build && mkdir build && cd build
cmake -Dprotobuf_BUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/usr -Dprotobuf_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON ../cmake
cmake --build . --target install
popd > /dev/null

echo "\nBuilding onnx"
# Building the version of onnx checked out along onnxruntime
ONNX_SRC="${ONNXRUNTIME_SRC}/cmake/external/onnx"

pushd "${ONNX_SRC}" > /dev/null

git submodule update --init --recursive

# Applying an additional patch to onnx
git apply "/workdir/patches/$(basename "${ONNX_SRC}")-$(cat "${ONNX_SRC}/VERSION_NUMBER").gitpatch"

# Needing a new version of pybind11 for working with python 3.11
git -C "./third_party/pybind11" fetch origin tag v2.11.1 --no-tags
git -C "./third_party/pybind11" checkout v2.11.1

CFLAGS="${CFLAGS} -Wno-error=incompatible-pointer-types" CXXFLAGS="${CXXFLAGS} -Wno-error=incompatible-pointer-types" CMAKE_ARGS=-DONNX_USE_LITE_PROTO=ON pip3 wheel --wheel-dir "/workdir/packages/wheels/" .

# Installing the onnx we have just built, which will be used during testing later
pip3 install --break-system-packages --no-index --find-links "/workdir/packages/wheels" onnx

popd > /dev/null

echo "\nBuilding onnxruntime"
CFLAGS="${CFLAGS} -fPIC -Wno-error=type-limits -Wno-error=deprecated-copy -Wno-error=stringop-overflow=" CXXFLAGS="${CXXFLAGS} -fPIC -Wno-error=type-limits -Wno-error=deprecated-copy -Wno-error=stringop-overflow= -I /usr/local/cudnn/include" LDFLAGS="-fPIC -L /usr/local/cudnn/lib -L /usr/local/cuda/lib64" ./build.sh --use_cuda --cudnn_home /usr/local/cudnn --cuda_home /usr/local/cuda --cmake_extra_defines CMAKE_CUDA_COMPILER='/usr/local/cuda/bin/nvcc' CMAKE_CUDA_FLAGS="-ccbin ${CXX} -std=c++11" CMAKE_CUDA_ARCHITECTURES='20;30;50;60' --parallel --config RelWithDebInfo --build_shared_lib --skip_submodule_sync --build_wheel

mv ./build/Linux/RelWithDebInfo/dist/onnxruntime_gpu*.whl "/workdir/packages/wheels"

popd > /dev/null



