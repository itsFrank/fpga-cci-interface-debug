
#include "afu_json_info.h"

#include "external/opae_utils.h"
#include "external/simple_cli.h"
#include "afu_control.h"

#include <iostream>
#include <fstream>
#include <string>

inline bool is_file_exist(const char *fileName)
{
    std::ifstream infile(fileName);
    return infile.good();
}

void spinASEReady(const char* arg_0) {
    if(std::string(arg_0).substr( std::string(arg_0).length() - 3 ) == "ase") {
        std::cout << "ASE Version - Waiting for ase_ready file to be available" << std::endl;
        std::string path = std::string(getenv("ASE_WORKDIR")) + std::string("/.ase_ready.pid");
        while (!is_file_exist(path.c_str()));
    }
}

int main(int argc, char** argv) {
    spinASEReady(argv[0]);

    //CLI
    scli::CLI options("Interface Debug", "interface_debug", "An FPGA-based graph analytics accelerator framework");

    options.addOption("w", "-w", "workspace size in log2(CLs)");
    options.addOption("d", "-d", "data size in log2(CLs)");

    options.parse(argc, argv);

    if (!options.is("d")) {
        std::cout << options.genHelp() << std::endl;
        std::cout << "Option -d is required" << std::endl;
        exit(-1);
    }

    int log2_data_cls = options.asInt("d");
    int log2_workspace_cls = options.is("w") ? options.asInt("w") : options.asInt("d");

    if (log2_workspace_cls < log2_data_cls) {
        std::cout << "Num workspace CLs must be larger than data CLs" << std::endl;
        exit(-1);
    }

    int num_data_cls = 1 << log2_data_cls;
    int num_padding_cls = (1 << log2_workspace_cls) - num_data_cls;

    std::cout << "Run Configuration:" << std::endl;
    std::cout << "\tData CLs  : " << num_data_cls << std::endl;
    std::cout << "\tRead CLs  : " << (num_data_cls + num_padding_cls) << std::endl;
    std::cout << "\tTotal CLs : " << (2 * (num_data_cls + num_padding_cls)) << std::endl;

    // Allocate AFU workspace
    opaeutils::AFU_Handle* afu_handle = new opaeutils::AFU_Handle("092a3e62-81c5-499a-ae2c-62ff4788fadd");
    afu_handle->addBuffer("afu_ctrl", 1);
    afu_handle->addBuffer("afu_stts", 1);
    afu_handle->addBuffer("rd_data", num_data_cls);
    afu_handle->addBuffer("rd_pad", num_padding_cls);
    afu_handle->addBuffer("wr_data", num_data_cls);
    afu_handle->addBuffer("wr_pad", num_padding_cls);

    if (!afu_handle->allocateWorkspace()) std::cout << "ERROR ALLOC WORKSPACE" << std::endl;

    // Assign worskpace pointers
    uint64_t* afu_ctrl = afu_handle->getBufferPtr("afu_ctrl");
    uint64_t* afu_stts = afu_handle->getBufferPtr("afu_stts");
    uint64_t* afu_rd_data = afu_handle->getBufferPtr("rd_data");
    uint64_t* afu_wr_data = afu_handle->getBufferPtr("wr_data");

    // Initialize & start AFU
    uint8_t afu_nonce = AFU_initControl(afu_handle, afu_ctrl, afu_stts, false);
    
    // Set read data
    for (int i = 0; i < num_data_cls * 8; i++) {
        afu_rd_data[i] = i + 1;
    }

    // Run kernel
    std::cout << "Starting AFU kernel" << std::endl;
    AFU_sendControl(AFU_CONTROL::START_RUN, afu_ctrl, afu_stts, afu_rd_data, afu_wr_data, num_data_cls, afu_nonce);
    // Wait kernel complete
    AFU_waitStatus(afu_stts, AFU_STATUS::DONE);
    std::cout << "AFU kernel done" << std::endl;
    std::cout << "AFU wrote " << afu_stts[1] << " cls" << std::endl;

    // Verify read data
    for (int i = 0; i < num_data_cls * 8; i++) {
        if (afu_rd_data[i] != afu_wr_data[i]) {
            std::cout << "ERROR** Index: " << i << ": expected( " << afu_rd_data[i] << " ), found( " << afu_wr_data[i] << " )" << std::endl;
        }
    }

    // Shutdown AFU
    std::cout << "Shutting down AFU" << std::endl;
    AFU_sendControl(AFU_CONTROL::SHUTDOWN, afu_ctrl, afu_stts, afu_nonce);
    AFU_waitState(afu_handle, AFU_STATE::SHUTDOWN);
    
    delete afu_handle;

    return 0;
}