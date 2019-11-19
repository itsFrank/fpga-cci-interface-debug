#ifndef IFDBG_AFU_CONTROL_H
#define IFDBG_AFU_CONTROL_H

#include "external/opae-common/opae_svc_wrapper.h"
#include "external/opae-common/csr_mgr.h"

#include "external/opae_utils.h"
#include <iostream>

enum class AFU_CONTROL : uint64_t {
    NONE        = 0,
    START_RUN   = 1,
    SHUTDOWN    = 2
};

enum class AFU_STATUS : uint64_t {
    NONE = 0,
    DONE = 3
};

enum class AFU_STATE : uint64_t {
    IDLE            = 0,
    CTRL            = 1,
    RUN             = 2,
    DONE            = 3,
    SHUTDOWN        = 4,
    SHUTDOWN_WAIT   = 5
};

int AFU_initControl(CSR_MGR &afu_csrs, uint64_t* afu_ctrl_ptr, uint64_t* afu_stts_ptr, bool quiet = true) {
    // Send control & status addresses to AFU
    if (!quiet) std::cout << "Writing AFU CTRL & STTS addresses to CSR 1 & 2 - " << std::hex << afu_ctrl_ptr << std::dec << " -- "  << std::hex << afu_stts_ptr << std::dec << std::endl;
    afu_csrs.writeCSR(1, (uint64_t) afu_ctrl_ptr);
    afu_csrs.writeCSR(2, (uint64_t) afu_stts_ptr);

    // Wait for AFU to confirm addresses have been recieved
    while (afu_csrs.readCSR(1) != (uint64_t)afu_ctrl_ptr){}
    while (afu_csrs.readCSR(2) != (uint64_t)afu_stts_ptr){}
    if (!quiet) std::cout << "AFU CTRL & STTS addresses have been latched by AFU" << std::endl;
    if (!quiet) std::cout << "Starting AFU..." << std::endl;
    afu_csrs.writeCSR(0, 1);

    return afu_csrs.readCSR(7); // Return current value of nonce
}

// nonce is a value the AFU uses to determine if data at the control address is stale or not
// nonce must be different from the previous value for AFU to consider data at control address valid
void AFU_sendControl(AFU_CONTROL control_code, uint64_t* afu_ctrl_ptr, uint64_t* afu_stts_ptr, uint8_t &nonce, bool quiet = true) {
    // Set local status code to none
    afu_stts_ptr[0] = (uint64_t)AFU_STATUS::NONE;
    
    // Populate control instruction
    afu_ctrl_ptr[0] = (uint64_t)control_code;
    nonce += 1;
    ((uint8_t*)afu_ctrl_ptr)[63] = nonce;
}

void AFU_sendControl(AFU_CONTROL control_code, uint64_t* afu_ctrl_ptr, uint64_t* afu_stts_ptr, uint64_t* read_data_ptr, uint64_t* write_data_ptr, uint64_t read_data_cl_count, uint8_t &nonce, bool quiet = true) {
    // Set local status code to none
    afu_stts_ptr[0] = (uint64_t)AFU_STATUS::NONE;

    // Populate control instruction
    afu_ctrl_ptr[0] = (uint64_t)control_code;
    afu_ctrl_ptr[1] = (uint64_t) read_data_ptr;
    afu_ctrl_ptr[2] = (uint64_t) write_data_ptr;
    afu_ctrl_ptr[3] = read_data_cl_count;
    nonce += 1;
    ((uint8_t*)afu_ctrl_ptr)[63] = nonce;
}

void AFU_waitStatus(uint64_t* afu_stts_ptr, AFU_STATUS status_code) {
    volatile uint64_t& current_status = afu_stts_ptr[0];
    struct timespec tim;
    tim.tv_sec  = 0;
    tim.tv_nsec = 10;
    while(current_status != (uint64_t)status_code) {
        nanosleep(&tim, NULL);
    }
}

void AFU_waitState(CSR_MGR &afu_csrs, AFU_STATE state) {
    while (afu_csrs.readCSR(0) != (uint64_t)state){}
}

#endif