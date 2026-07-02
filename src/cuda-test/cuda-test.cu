#include <cstdio>
#include <cstdlib>
#include "cuda.h"


#define JUMP_IF_ERROR(check, label, error_msg, ...) do { \
  cudaError_t result = check; \
  if (result != cudaSuccess) { \
    printf(error_msg ": %s\n", ## __VA_ARGS__, cudaGetErrorName(result)); \
    goto label; \
  } \
} while (false)

namespace {

constexpr int THREAD_LOOP_SIZE = 100;

extern "C" {
  __global__ void testing_kernel(float *data) {
    const int global_index = blockIdx.x * blockDim.x + threadIdx.x;
    for (int i = 0; i < THREAD_LOOP_SIZE; ++i) {
      data[global_index] += 1.0f;
    }
  }
}

}

int main(int argc, char** argv)
{  
  bool is_error = true;
  int device_id = -1;
  cudaDeviceProp device_prop = {0};
  constexpr int THREAD_NUM = 32, BLOCK_NUM = 32;
  constexpr size_t BUFFER_SIZE_IN_BYTES = sizeof(float) * THREAD_NUM * BLOCK_NUM;
  float *device_data = nullptr, host_data[THREAD_NUM*BLOCK_NUM] = {0};

  device_prop.major = 2;
  device_prop.minor = 0;
  JUMP_IF_ERROR(
      cudaChooseDevice(&device_id, &device_prop),
      no_free_exit,
      "No device with CC >= 2.0 exists");
  JUMP_IF_ERROR(
      cudaSetDevice(device_id),
      no_free_exit,
      "Failed to make device %d the current device", device_id);

  JUMP_IF_ERROR(
      cudaGetDeviceProperties(&device_prop, device_id),
      no_free_exit,
      "Failed to query the property of device %d", device_id);

  printf("Testing on GPU device %d (%s), CC = %d.%d\n",
      device_id, device_prop.name, device_prop.major, device_prop.minor);


  JUMP_IF_ERROR(
      cudaMalloc(&device_data, BUFFER_SIZE_IN_BYTES),
      no_free_exit,
      "Failed to allocate memory on device %d", device_id);

  JUMP_IF_ERROR(
      cudaMemset(device_data, 0, BUFFER_SIZE_IN_BYTES),
      free_exit,
      "Failed to set the content of the allocated buffer to 0");

  testing_kernel<<<BLOCK_NUM, THREAD_NUM>>>(device_data);
  JUMP_IF_ERROR(
      cudaGetLastError(),
      free_exit,
      "Failed to launch the testing kernel");
  JUMP_IF_ERROR(
      cudaDeviceSynchronize(),
      free_exit,
      "Failed to synchronize with device %d", device_id);
  JUMP_IF_ERROR(
      cudaMemcpy(host_data, device_data, BUFFER_SIZE_IN_BYTES, cudaMemcpyDeviceToHost),
      free_exit,
      "Failed to copy results from device %d to the host", device_id);

  for (const float &d : host_data) {
    if (std::abs(d - THREAD_LOOP_SIZE) > 1e-6f) {
      printf("Failed to pass the correctness check\n");
      goto free_exit;
    }
  }

  printf("OK\n");
  is_error = false;

free_exit:
  cudaFree(device_data);
no_free_exit:
  return is_error;

}
