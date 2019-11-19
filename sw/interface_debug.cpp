
#include "afu_json_info.h"

#include "external/opae-common/opae_svc_wrapper.h"
#include "external/opae-common/csr_mgr.h"

#include "external/opae_utils.h"
#include "external/simple_cli.h"
#include "afu_control.h"
#include "utils.h"

#include <iostream>
#include <fstream>
#include <string>

int main(int argc, char** argv) {
    spinASEReady(argv[0]);

    //CLI
    scli::CLI options("Interface Debug", "interface_debug", "An FPGA-based graph analytics accelerator framework");

    options.addOption("w", "-w", "workspace size in log2(CLs)");
    options.addOption("d", "-d", "data size in log2(CLs)");
    options.addOption("v", "-v", "validate results");

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

    bool validate = options.is("v");
    int num_data_cls = 1 << log2_data_cls;
    int num_padding_cls = (1 << log2_workspace_cls) - num_data_cls;

    std::cout << "Run Configuration:" << std::endl;
    std::cout << "\tData CLs  : " << num_data_cls << std::endl;
    std::cout << "\tRead CLs  : " << (num_data_cls + num_padding_cls) << std::endl;
    std::cout << "\tTotal CLs : " << (2 * (num_data_cls + num_padding_cls)) << std::endl;

    // Allocate AFU workspace
    OPAE_SVC_WRAPPER fpga(AFU_ACCEL_UUID);
    assert(fpga.isOk());
    CSR_MGR csrs(fpga);

    opaeutils::AFUWorkspace afu_workspace; //("092a3e62-81c5-499a-ae2c-62ff4788fadd");
    afu_workspace.addBuffer("afu_ctrl", 1);
    afu_workspace.addBuffer("afu_stts", 1);
    afu_workspace.addBuffer("rd_data", num_data_cls);
    afu_workspace.addBuffer("wr_data", num_data_cls);
    afu_workspace.addBuffer("rd_pad", num_padding_cls);
    afu_workspace.addBuffer("wr_pad", num_padding_cls);

    // Allocate workspace & pin memory
    auto buf_handle = fpga.allocBuffer(afu_workspace.getWorkspaceBytes());
    auto buf = reinterpret_cast<volatile uint64_t*>(buf_handle->c_type());
    assert(NULL != buf);

    // Populate pointer addresses
    afu_workspace.allocateWorkspace(buf);

    // Assign worskpace pointers
    uint64_t* afu_ctrl = afu_workspace.getBufferPtr("afu_ctrl");
    uint64_t* afu_stts = afu_workspace.getBufferPtr("afu_stts");
    uint64_t* afu_rd_data = afu_workspace.getBufferPtr("rd_data");
    uint64_t* afu_wr_data = afu_workspace.getBufferPtr("wr_data");

    // Initialize & start AFU
    uint8_t afu_nonce = AFU_initControl(csrs, afu_ctrl, afu_stts, false);
    
    // Set read data (no need to write data if we are not validating)
    if (validate) {
        for (int i = 0; i < num_data_cls * 8; i++) {
            afu_rd_data[i] = i + 1;
        }
    }

    TimerUtil timer;

    // Run kernel
    std::cout << "Starting AFU kernel" << std::endl;
    timer.start();
    AFU_sendControl(AFU_CONTROL::START_RUN, afu_ctrl, afu_stts, afu_rd_data, afu_wr_data, num_data_cls, afu_nonce);
    // Wait kernel complete
    AFU_waitStatus(afu_stts, AFU_STATUS::DONE);
    double elapsed_s = timer.elapsed_s();
    std::cout << "AFU kernel done in " << elapsed_s << " seconds" << std::endl;
    std::cout << "AFU wrote " << afu_stts[1] << " cls" << std::endl;

    // Verify read data
    if (validate) {
        bool valid = true;
        for (int i = 0; i < num_data_cls * 8; i++) {
            if (afu_rd_data[i] != afu_wr_data[i]) {
                std::cout << "ERROR** Index: " << i << ": expected( " << afu_rd_data[i] << " ), found( " << afu_wr_data[i] << " )" << std::endl;
                valid = false;
                break;
            }
        }
        if (valid) {
            std::cout << "AFU ran successfully" << std::endl;
        } else {
            std::cout << "ERROR in AFU run" << std::endl;
        }
    }

    // Shutdown AFU
    std::cout << "Shutting down AFU" << std::endl;
    AFU_sendControl(AFU_CONTROL::SHUTDOWN, afu_ctrl, afu_stts, afu_nonce);
    AFU_waitState(csrs, AFU_STATE::SHUTDOWN);
    
    // MPF VTP (virtual to physical) statistics
    auto mpf = fpga.mpf;
    if (mpfVtpIsAvailable(*mpf))
    {
        mpf_vtp_stats vtp_stats;
        mpfVtpGetStats(*mpf, &vtp_stats);

        std::cout << "#" << std::endl;
        if (vtp_stats.numFailedTranslations)
        {
            std::cout << "# VTP failed translating VA: 0x" << std::hex << uint64_t(vtp_stats.ptWalkLastVAddr) << std::dec << std::endl;
        }
        std::cout << "# VTP PT walk cycles: " << vtp_stats.numPTWalkBusyCycles << std::endl
             << "# VTP L2 4KB hit / miss: " << vtp_stats.numTLBHits4KB << " / "
             << vtp_stats.numTLBMisses4KB << std::endl
             << "# VTP L2 2MB hit / miss: " << vtp_stats.numTLBHits2MB << " / "
             << vtp_stats.numTLBMisses2MB << std::endl;
    }

    // delete afu_workspace;

    return 0;
}