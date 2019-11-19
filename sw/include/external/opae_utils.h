/*
    File: opae_utils.h                                                                                                                              
    Author: Francis O'Brien                                                                                                                           
    Email: francis.obrien@mail.utoronto.ca                                                                                                            
    Create Date: 07-04-2018                                                                                                                             
    -----------------------------------------                                                                                                         
    Description                                                                                                                                              
        A set of functions and objects to simplify CPU-side workspace and buffer management for Intel HARP OPAE AFUs
    -----------------------------------------
    History                                                                                                                                           
        07-04-2018 :    created  
*/


#pragma once
#ifndef LIB_OPAEUTILS_H
#define LIB_OPAEUTILS_H

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <stdexcept>
#include <time.h>

#include <cassert>

#define BYTES_PER_CL 64
#define INT64_PER_CL 8
#define INT32_PER_CL 16

#define DEBUG(msg) std::cout << __FILE__ << " (" << __LINE__ << "): " << msg << std::endl;

namespace opaeutils {
    using namespace std;

    struct buffer_t {
        uint64_t num_cls;
        uint64_t cl_offset;
    };

    class AFUWorkspace {
        private:
            volatile uint64_t* p_workspace = 0;

            uint64_t cl_offset;

            map<string, buffer_t> buffers;
            vector<string> buffer_order;

        public:

            static buffer_t MakeBuffer(uint64_t num_cls, uint64_t cl_offset) {
                buffer_t buffer;
                buffer.num_cls = num_cls;
                buffer.cl_offset = cl_offset;

                return buffer;
            }

            AFUWorkspace() {
                this->cl_offset = 0;
                this->p_workspace = 0;
            }

            uint64_t getWorkspaceCLs() {
                return this->cl_offset;
            }

            uint64_t getWorkspaceBytes() {
                return this->cl_offset * BYTES_PER_CL;
            }

            uint64_t getBufferCLs(string name) {
                return this->buffers[name].num_cls;
            }

            uint64_t getBufferBytes(string name) {
                return this->buffers[name].num_cls * BYTES_PER_CL;
            }


            bool allocateWorkspace(uint64_t* p_workspace) {
                this->p_workspace = p_workspace;
            }

            bool allocateWorkspace(volatile uint64_t* p_workspace) {
                this->p_workspace = (uint64_t*) p_workspace;
            }

            void addBuffer(string name, uint64_t numCL) {
                if (this->p_workspace != 0) {
                    cerr << "[OPAE-UTILS] ERROR: Cannot add new buffer after allocating workspace" << endl;
                    exit(1);
                }

                this->buffer_order.push_back(name);
                this->buffers[name] = MakeBuffer(numCL, this->cl_offset);
                this->cl_offset += numCL;
            }

            void addBuffer(string name, int num_elements, size_t size_elements) {
                if (this->p_workspace != 0) {
                    cerr << "[OPAE-UTILS] ERROR: Cannot add new buffer after allocating workspace" << endl;
                    exit(1);
                }

                uint64_t bytes = (uint64_t)(num_elements * size_elements);
                uint64_t numCL = (bytes / BYTES_PER_CL) + (bytes % BYTES_PER_CL == 0 ? 0 : 1);

                this->buffer_order.push_back(name);
                this->buffers[name] = MakeBuffer(numCL, this->cl_offset);
                this->cl_offset += numCL;
            }

            uint64_t* getWorkspacePtr(){
                if (!this->p_workspace != 0) {
                    cerr << "[OPAE-UTILS] ERROR: Allocate workspace before requesting pointers" << endl;
                    exit(1);
                }

                return const_cast<uint64_t*>(this->p_workspace);
            }

            uint64_t* getBufferPtr(string name) {
                 if (!this->p_workspace != 0) {
                    cerr << "[OPAE-UTILS] ERROR: Allocate workspace before requesting pointers" << endl;
                    exit(1);
                }

                uint64_t* ptr = const_cast<uint64_t*>(this->p_workspace);
                return ptr + (this->buffers[name].cl_offset * (BYTES_PER_CL / sizeof(uint64_t)));
            }

            void dropWorkspace() {
                this->p_workspace = 0;
            }
    };
}


#endif