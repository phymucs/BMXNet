ifndef config
ifdef CXXNET_CONFIG
	config = $(CXXNET_CONFIG)
else ifneq ("$(wildcard ./config.mk)","")
	config = config.mk
else
	config = make/config.mk
endif
endif

ifndef DMLC_CORE
	DMLC_CORE = dmlc-core
endif

ifndef RABIT
	RABIT = rabit
endif

# use customized config file
include $(config)
include mshadow/make/mshadow.mk
include $(DMLC_CORE)/make/dmlc.mk

# all tge possible warning tread
WARNFLAGS= -Wall
CFLAGS = -DMSHADOW_FORCE_STREAM $(WARNFLAGS)

# CFLAGS for debug
ifeq ($(DEBUG),0)
	CFLAGS += -O3
else
	CFLAGS += -g -O0
endif
CFLAGS += -I./mshadow/ -I./dmlc-core/include -fPIC -Iinclude $(MSHADOW_CFLAGS)
LDFLAGS = -pthread $(MSHADOW_LDFLAGS) $(DMLC_LDFLAGS)
NVCCFLAGS = --use_fast_math -g -O3 -ccbin $(CXX) $(MSHADOW_NVCCFLAGS)
ROOTDIR = $(CURDIR)

ifndef LINT_LANG
	LINT_LANG="all"
endif

# setup opencv
ifeq ($(USE_OPENCV),1)
	CFLAGS+= -DCXXNET_USE_OPENCV=1
	LDFLAGS+= `pkg-config --libs opencv`
else
	CFLAGS+= -DCXXNET_USE_OPENCV=0
endif

ifeq ($(USE_CUDNN), 1)
	CFLAGS += -DCXXNET_USE_CUDNN=1
	LDFLAGS += -lcudnn
endif

ifneq ($(ADD_CFLAGS), NONE)
	CFLAGS += $(ADD_CFLAGS)
endif

ifneq ($(ADD_LDFLAGS), NONE)
	LDFLAGS += $(ADD_LDFLAGS)
endif

#ENGINE=simple_engine.o dag_engine.o
ENGINE=naive_engine.o
BIN = tests/test_simple_engine
OBJ = narray_function_cpu.o
OBJCXX11 = batch_norm_cpu.o reshape_cpu.o narray.o c_api.o operator.o symbol.o storage.o fully_connected_cpu.o static_graph.o activation_cpu.o graph_executor.o softmax_cpu.o elementwise_sum_cpu.o pooling_cpu.o convolution_cpu.o io.o iter_mnist.o $(ENGINE)
CUOBJ =
SLIB = lib/libmxnet.so
ALIB = lib/libmxnet.a
LIB_DEP = $(DMLC_CORE)/libdmlc.a

ifeq ($(USE_CUDA), 1)
	CUOBJ += batch_norm_gpu.o reshape_gpu.o narray_function_gpu.o fully_connected_gpu.o activation_gpu.o elementwise_sum_gpu.o pooling_gpu.o softmax_gpu.o convolution_gpu.o
endif

.PHONY: clean all test lint doc

all: $(ALIB) $(SLIB) $(BIN)

$(DMLC_CORE)/libdmlc.a:
	+ cd $(DMLC_CORE); make libdmlc.a config=$(ROOTDIR)/$(config); cd $(ROOTDIR)

storage.o: src/storage/storage.cc
naive_engine.o:  src/dag_engine/naive_engine.cc
dag_engine.o: src/dag_engine/dag_engine.cc
simple_engine.o: src/dag_engine/simple_engine.cc 
narray.o: src/narray/narray.cc
narray_function_cpu.o: src/narray/narray_function.cc src/narray/narray_function-inl.h
narray_function_gpu.o: src/narray/narray_function.cu src/narray/narray_function-inl.h
symbol.o: src/symbol/symbol.cc
graph_executor.o: src/symbol/graph_executor.cc
static_graph.o : src/symbol/static_graph.cc
operator.o: src/operator/operator.cc
c_api.o: src/c_api.cc
fully_connected_cpu.o: src/operator/fully_connected.cc
fully_connected_gpu.o: src/operator/fully_connected.cu
activation_cpu.o: src/operator/activation.cc
activation_gpu.o: src/operator/activation.cu
elementwise_sum_cpu.o: src/operator/elementwise_sum.cc
elementwise_sum_gpu.o: src/operator/elementwise_sum.cu
pooling_cpu.o: src/operator/pooling.cc
pooling_gpu.o: src/operator/pooling.cu
softmax_cpu.o: src/operator/softmax.cc
softmax_gpu.o: src/operator/softmax.cu
convolution_cpu.o: src/operator/convolution.cc
convolution_gpu.o: src/operator/convolution.cu
reshape_cpu.o: src/operator/reshape.cc
reshape_gpu.o: src/operator/reshape.cu
batch_norm_cpu.o: src/operator/batch_norm.cc
batch_norm_gpu.o: src/operator/batch_norm.cu
io.o: src/io/io.cc
iter_mnist.o: src/io/iter_mnist.cc

lib/libmxnet.a: $(OBJ) $(OBJCXX11) $(CUOBJ) $(LIB_DEP)
lib/libmxnet.so: $(OBJ) $(OBJCXX11) $(CUOBJ) $(LIB_DEP)

tests/test_storage: tests/test_storage.cc lib/libmxnet.a
tests/test_simple_engine: tests/test_simple_engine.cc lib/libmxnet.a

$(BIN) :
	$(CXX) $(CFLAGS) -std=c++0x -o $@ $(filter %.cpp %.o %.c %.a %.cc, $^) $(LDFLAGS)

$(OBJ) :
	$(CXX) -c $(CFLAGS) -o $@ $(filter %.cpp %.c %.cc, $^)

$(OBJCXX11) :
	$(CXX) -std=c++0x -c $(CFLAGS) -o $@  $(filter %.cpp %.c %.cc, $^)

$(SLIB) :
	$(CXX) $(CFLAGS) -shared -o $@ $(filter %.cpp %.o %.c %.a %.cc, $^) $(LDFLAGS)

$(ALIB): $(OBJ) $(OBJCXX11)
	ar cr $@ $+

$(CUOBJ) :
	$(NVCC) -c -o $@ $(NVCCFLAGS) -Xcompiler "$(CFLAGS)" $(filter %.cu, $^)

$(CUBIN) :
	$(NVCC) -o $@ $(NVCCFLAGS) -Xcompiler "$(CFLAGS)" -Xlinker "$(LDFLAGS)" $(filter %.cu %.cpp %.o, $^)


lint:
	python dmlc-core/scripts/lint.py mxnet ${LINT_LANG} include src scripts test python

doxygen:
	doxygen doc/Doxyfile

clean:
	$(RM) $(OBJ) $(OBJCXX11) $(BIN) $(CUBIN) $(CUOBJ) $(SLIB) $(ALIB) *~ */*~ */*/*~ */*/*/*~
	cd $(DMLC_CORE); make clean; cd -