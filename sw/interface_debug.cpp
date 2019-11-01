
#include "afu_json_info.h"

#include "external/opae_utils.h"
#include "external/simple_cli.h"

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

    options.parse(argc, argv);

    opaeutils::AFU_Handle afu_handle("092a3e62-81c5-499a-ae2c-62ff4788fadd");
    afu_handle.addBuffer("afu_ctrl", 1);
    afu_handle.addBuffer("data", 30);
    if (!afu_handle.allocateWorkspace()) std::cout << "ERROR ALLOC WORKSPACE" << std::endl;

    uint64_t* afu_ctrl = afu_handle.getBufferPtr("afu_ctrl");
    afu_ctrl[0] = 1; // set code to 0 (NONE)
    afu_ctrl[1] = (uint64_t) afu_handle.getBufferPtr("data");
    afu_ctrl[2] = 0;
    afu_ctrl[3] = 30;
    ((uint8_t*)afu_ctrl)[63] = 1; // set nonce to 0

    std::cout << "Writing AFU CTRL address to CSR 1 - " << std::hex << afu_ctrl << std::dec << std::endl;
    afu_handle.writeCSR(1, (uint64_t) afu_handle.getBufferPtr("afu_ctrl"));

    while (afu_handle.readCSR(1) != (uint64_t)afu_ctrl){}
    std::cout << "AFU CTRL address has been latched by AFU" << std::endl;
    std::cout << "Starting AFU..." << std::endl;
    afu_handle.writeCSR(0, 1);

    while (true) {}

    return 0;
}