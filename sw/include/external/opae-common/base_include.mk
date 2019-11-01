##
## Define base source files
##

include ./include/external/opae-common/common_include.mk


BASE_FILE_PATH = include/external/opae-common
BASE_FILE_NAME = opae_svc_wrapper
BASE_FILE_SRC = $(BASE_FILE_PATH)/$(BASE_FILE_NAME).cpp
BASE_FILE_INC = $(BASE_FILE_PATH)/$(BASE_FILE_NAME).h $(BASE_FILE_PATH)/csr_mgr.h

VPATH = .:$(BASE_FILE_PATH)

CPPFLAGS += -I.
LDFLAGS += -lboost_program_options -lMPF-cxx -lMPF -lopae-cxx-core
