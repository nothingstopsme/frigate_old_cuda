CUDA_PATH ?= /usr/local/cuda
NVCC_FLAGS ?= -ccbin $(CXX) -gencode arch=compute_20,code=compute_20 -gencode arch=compute_20,code=sm_20 -O2
override NVCC_FLAGS += -I $(CUDA_PATH)/include -std=c++11 -m64
NVCC := $(CUDA_PATH)/bin/nvcc

PROGRAMME_NAME := cuda-test

test: $(PROGRAMME_NAME)
	@./$(PROGRAMME_NAME)

$(PROGRAMME_NAME): $(PROGRAMME_NAME).cu
	$(NVCC) $(NVCC_FLAGS) $< "$(CUDA_PATH)/lib64/libcudart_static.a" -o $@


clean:
	@rm -f $(PROGRAMME_NAME)
