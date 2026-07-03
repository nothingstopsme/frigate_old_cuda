# frigate_old_cuda
This project tries to enable [frigate](https://github.com/blakeblackshear/frigate) to exploit your ***old but still working*** NVIDIA GPUs, of which compute capability (CC) can be as low as 2.x (limited support) / 3.x.

## Prerequisites
Please follow the instructions from [here](https://docs.frigate.video/configuration/hardware_acceleration_video#nvidia-gpus) to make sure that
* [x] A driver compatible with your old GPU has been installed on your ***host*** machine. If your OS distribution does not provide such driver packages anymore, your best chance is to peruse [NVIDIA driver archives](https://download.nvidia.com/XFree86/Linux-x86_64/) and download the corresponding installer to install it yourself; also note that only the driver part is necessary for this setup, and it should be installed on the host side.
* [x] [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) has been installed and your compose file / command to launch the frigate container has been adapted accordingly, so that your GPU become visible inside containers

The bottom line is the command `nvidia-smi` should be available inside the frigate container and report information about your GPU once executed; you can verify this by running (taking "frigate:0.17.1" as an example)
```bash
sudo docker run --runtime=nvidia --gpus=all --privileged --rm -it --entrypoint '/bin/bash' \
  'ghcr.io/blakeblackshear/frigate:0.17.1' -c nvidia-smi
```

## Component Replacement
A list of compatible versions of runtimes/libraries/apps have been put together to replace those not supporting the target GPU generations:
* CUDA 8.0.61 (the last version supporting CC 2.x) ([source](https://developer.nvidia.com/cuda-80-ga2-download-archive))
* CUDNN 7.2.1 (the newest version I found that can work with CUDA 8) ([source](https://developer.nvidia.com/w/compute/machine-learning/repos/ubuntu1604/x86_64/))
* onnxruntime 1.1.2 (supposedly compatible with CUDNN 7.2, as mentioned in [this requirement table](https://onnxruntime.ai/docs/execution-providers/CUDA-ExecutionProvider.html#cuda-10x) on the website of onnxruntime) ([source](https://github.com/microsoft/onnxruntime/tree/v1.1.2))
* onnx 1.6.0 (the version paired with onnxruntime 1.1 as a submodule) ([source](https://github.com/onnx/onnx/tree/v1.6.0))
* nv-codec-headers 8.1.24.15 (compatible with CUDA 8) ([source](https://github.com/FFmpeg/nv-codec-headers/tree/n8.1.24.15))
* ffmpeg 7.0.3 (just picking a version default to one of recent frigate containers) ([source](https://github.com/FFmpeg/FFmpeg/tree/n7.0.3))

For the convenience of testing, pre-built packages are [available](https://github.com/nothingstopsme/frigate_old_cuda/releases/latest) and can be directly installed into the frigate container:
* Binaries extracted from CUDA and CUDNN have been merged as a single package.
* Apart from CUDA and CUDNN, others were built from respective sources patched with custom fixes for compile/compatibility issues.
* Some of headers inside CUDA toolkit and g++ includes have also been patched so that more modern gcc-11/g++-11 can serve as a host compiler for creating those pre-builts.

All patches implemented in this project can be found [here](patches)

## Limitation
* For GPUs of CC 2.x

  1. The lowest compute capability ever supported by CUDNN, which is the key library to many CUDA versions of operators implemented in onnxruntime, is 3.0. Due to lack of CUDNN support, when executed on such GPUs a number of operators have to fall back to their CPU counterparts, and this has a huge impact on the degree of speedup of object detection models where the dominant operator, 2D convolution, is also accelerated through CUDNN api. For instance, with the yolov5nu model the inference time reported by frigate on my device (CC 2.1) showed that the GPU executor just spent similar running time to the one taken by the CPU executor, suggesting that most of operators were not accelerated at all.

  2. Their microarchitecture is presumably ***Fermi***, which implies there is no hardware support for ***NVENC***, and thus requests for that feature from encoders of ffmpeg will result in errors; though this limitation is only relevant if you need to re-encode your video streams.
   
* For GPUs of CC 3.x upto 6.x

  onnxruntime and ffmpeg should be able to fully benefit from your GPU (as far as all available CUDA kernels they can run); however, since I do not have devices of each capability to confirm how much the performance gain is (if any), there is no guarantee of significant boost in execution time through this acceleration.

## Quick Start
1. Download "packages.zip" from the [release](https://github.com/nothingstopsme/frigate_old_cuda/releases/latest) and unzip it.
2. Download [frigate-cuda.dockerfile](docker/frigate-cuda.dockerfile) and create a new image derived from the frigate container you want to use by running
   ```bash   
   sudo docker build -t ${TAG_OF_THE_NEW_IMAGE} -f "${PATH_TO_THE_PARENT_FOLDER_OF_DOCKERFILE}/frigate-cuda.dockerfile" \
     --build-context packages="${PATH_TO_UNZIPPED_PACKAGES}" --build-arg BASE_IMAGE="${FRIGATE_IMAGE_TAG}" .
   ```
   Note that in addition to package installation, "[frigate-cuda.dockerfile](docker/frigate-cuda.dockerfile)" also
   1. Replaces the filter "scale_cuda" used in "ffmpeg_presets.py", which is a configuration script located inside the frigate container, with "scale_npp"
   2. Updates environment variables so that the newly installed version of ffmpeg becomes the default one
   
   Please check if the two changes above conflict with your current configuration.
3. Follow the instructions from [here](https://docs.frigate.video/configuration/hardware_acceleration_video/#setup-decoder) to configure ffmpeg to run with hardware acceleration
4. Follow the instructions from [here](https://docs.frigate.video/configuration/object_detectors#onnx) to configure your detector and onnx model. Note that the installed onnxruntime 1.1.2 only supports onnx opset version upto ***11***; therefore, models to be run need to conform with that opset requirement, and in some cases it can be achieved by converting target models from other sources. For example, the yolo5 model I used during my test was converted from the corresponding pytorch model via the following python script (requiring `pip install ultralytics`)
   ```python
   from ultralytics import YOLO
   model = YOLO('yolov5nu.pt')
   model.export(format='onnx', opset=11, imgsz=320)
   ```   
5. With your configuration and model ready, update the image tag in your compose file / launch command to the new one and start the frigate container as usual

## Build
If you fancy building packages from sources yourself:
1. Clone this project.
2. Download "packages.zip" from the [release](https://github.com/nothingstopsme/frigate_old_cuda/releases/latest) and unzip it inside the project root folder. The main purpose of this step is to put the debian package "cuda-8.0.61+cudnn-7.2.1-full_0.0-0.deb" in place (should be located at `${PROJECT_ROOT}/packages/debs/cuda-8.0.61+cudnn-7.2.1-full_0.0-0.deb`), so that later we can establish a "build container" wrapping our build environment with that package installed inside.
3. Create an image of the build container by running
   ```bash
   cd ${PROJECT_ROOT}/docker
   sudo docker build -t frigate:build-img -f ./build-img.dockerfile \
     --build-context packages='../packages' \
     --build-context patches='../patches' \
     --build-context finite-math='../src/finite-math' \
     --build-arg BASE_IMAGE="${FRIGATE_IMAGE_TAG}" .
   ```
   Note that you also need to pick a base container image, and you could just use the frigate container as it gives you exactly the same environment as during runtime.
4. Launch build scripts inside the build container to build corresponding packages from scratch:

   ffmpeg
   ```bash
   cd ${PROJECT_ROOT}
   sudo docker run --runtime=nvidia --gpus=all --privileged --rm -it -v './:/workdir' \
     'frigate:build-img' -c "/bin/bash /workdir/scripts/build_ffmpeg.sh"
   ```
   onnx / onnxruntime
   ```bash
   cd ${PROJECT_ROOT}
   sudo docker run --runtime=nvidia --gpus=all --privileged --rm -it -v './:/workdir' \
     'frigate:build-img' -c "/bin/bash /workdir/scripts/build_onnxruntime.sh"
   ```
   Produced packages will be stored in `${PROJECT_ROOT}/packages/debs` or `${PROJECT_ROOT}/packages/wheels`, according to their types.

## Licence
While this project itself is licensed under GNU GPLv3, all the sources listed in this [section](#Component-Replacement) are also subject to terms and conditions from the original licence/agreement adopted by their providers, and those still apply to the resulting pre-built packages shared by this project. Please be cognisant of such additional liability you might have when using these packages, in particular ones depending on many external libraries of which some could have stringent licensing rules, like ffmpeg and the "non-free" codecs it compiles against.
