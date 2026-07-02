INSTALL_PREFIX :=
LIBNAME := libfinite-math.a

all: $(LIBNAME)

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(LIBNAME): $(subst .cc,.o,$(wildcard *.cc))
	$(AR) rcs $@ $^

install: $(LIBNAME)
	@if [ -d "$(INSTALL_PREFIX)" ]; then \
    cp $< $(INSTALL_PREFIX); \
    echo "$< installed"; \
  else \
    echo "[ERROR] INSTALL_PREFIX is not provided"; \
  fi
