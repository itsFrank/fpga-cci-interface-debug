include ./include/external/opae-common/base_include.mk

# Primary test name
TEST = interface_debug

# Build directory
OBJDIR = obj
CFLAGS += -I./$(OBJDIR)
CPPFLAGS += -I./$(OBJDIR)

CXX += -flto -finline-limit=100000 -finline-functions -ffast-math -funroll-all-loops -msse3 # optimization
CXX += $(FLGADD)
# Files and folders
SRCS = $(BASE_FILE_SRC)
OTHER_SRCS = $(shell find ./src -name "*.cpp")#$(wildcard src/**/*.cpp)
OBJS = $(addprefix $(OBJDIR)/,$(patsubst %.cpp,%.o,$(notdir $(SRCS))))

LOC_LIB = -I./include -I./opae-common -pthread

.PHONY: all clean getlibs $(TEST) $(TEST)_ase ase fpga g2b

# Targets
all: $(TEST) $(TEST)_ase 
#all: ase 

gdb: CXX+=-g
fpga: $(TEST)
ase: $(TEST)_ase 
 
# AFU info from JSON file, including AFU UUID
AFU_JSON_INFO = $(OBJDIR)/afu_json_info.h
$(AFU_JSON_INFO): ./$(TEST).json | objdir
	afu_json_mgr json-info --afu-json=$^ --c-hdr=$@
$(OBJS): $(AFU_JSON_INFO)

$(TEST): $(OBJS)
	$(CXX) $(CPPFLAGS) -O2 -std=c++11 -o $@ $(TEST).cpp $(OTHER_SRCS) $^ $(LDFLAGS) $(FPGA_LIBS) $(LOC_LIB)

$(TEST)_ase: $(OBJS)
	$(CXX) $(CPPFLAGS) -g -O2 -std=c++11 -o $@ $(TEST).cpp $(OTHER_SRCS) $^ $(LDFLAGS) $(ASE_LIBS) $(LOC_LIB)

$(OBJDIR)/%.o: %.cpp | objdir
	$(CXX) $(CPPFLAGS) $(CFLAGS) -c $< -o $@ $(LOC_LIB)

multi: $(AFU_JSON_INFO)
	$(CXX) $(CPPFLAGS) -O2 -std=c++11 -o $(TEST) $(TEST).cpp $(wildcard src/*/*.cpp) $(BASE_FILE_SRC) -fPIC $(LDFLAGS) $(FPGA_LIBS) $(LOC_LIB)

perf: $(AFU_JSON_INFO)
	awk 1 $(TEST).cpp $(OTHER_SRCS) > bundle.cpp
	$(CXX) $(CPPFLAGS) -O2 -std=c++11 -o $(TEST) bundle.cpp $(BASE_FILE_SRC) -fPIC $(LDFLAGS) $(FPGA_LIBS) $(LOC_LIB)

g2b:
	$(CXX) $(CPPFLAGS)-O2 -std=c++11 g2b.cpp -o g2b src/setup/graph_loading.cpp -I ./include -fPIC $(LDFLAGS) $(FPGA_LIBS) $(LOC_LIB) -g

clean:
	rm -rf $(TEST) $(TEST)_ase $(OBJDIR) g2b

objdir:
	@mkdir -p $(OBJDIR)

gdb: CXX+=-g
gdb: all

getlibs:
	cp ~/software/threadpool/threadpool.h ./include
