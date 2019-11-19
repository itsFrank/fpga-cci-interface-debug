#ifndef FG_UTILS_H
#define FG_UTILS_H

#include <vector>
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <sys/time.h>
#include <random>

#define PBSTR "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"
#define PBWIDTH 60
#define PBDELAY 10

inline void printProgress(double percentage)
{
    if (percentage > 1) percentage = 1;
    int val = (int) (percentage * 100);
    int lpad = (int) (percentage * PBWIDTH);
    int rpad = PBWIDTH - lpad;
    printf ("\r%3d%% [%.*s%*s]", val, lpad, PBSTR, rpad, "");
    fflush (stdout);
}


class TimerUtil {
    private:
        struct timeval start_time;

    public:
        TimerUtil() {}

        void start() {
            gettimeofday(&(this->start_time), NULL);
        }

        long elapsed_ms() {
            struct timeval end;
            long mtime, seconds, useconds;

            gettimeofday(&end, NULL);
            seconds  = end.tv_sec  - this->start_time.tv_sec;
            useconds = end.tv_usec - this->start_time.tv_usec;
            mtime = ((seconds) * 1000 + useconds/1000.0) + 0.5;
            return mtime;
        }

        long elapsed_us() {
            struct timeval end;
            long utime, seconds, useconds;

            gettimeofday(&end, NULL);
            seconds  = end.tv_sec  - this->start_time.tv_sec;
            useconds = end.tv_usec - this->start_time.tv_usec;
            utime = ((seconds * 1000000) + useconds);
            return utime;
        }

        double elapsed_s() {
            struct timeval end;
            long seconds, useconds;
            double stime;

            gettimeofday(&end, NULL);
            seconds  = end.tv_sec  - this->start_time.tv_sec;
            useconds = end.tv_usec - this->start_time.tv_usec;
            stime = seconds + (((double)useconds) / 1000000.0);
            return stime;
        }
};

class UniformRandomGenerator {
    private:
        std::random_device* rd; // obtain a random number from hardware
        std::mt19937* eng; // seed the generator
        std::uniform_int_distribution<>* distr; // define the range

    public:
        UniformRandomGenerator(int min, int max) {
            this->rd = new std::random_device();
            this->eng = new std::mt19937((*(this->rd))());
            this->distr = new std::uniform_int_distribution<>(min, max);
        }

        int gen() {
            return (*(this->distr))((*this->eng));
        }
};

inline bool is_file_exist(const char *fileName)
{
    std::ifstream infile(fileName);
    return infile.good();
}

inline void spinASEReady(const char* arg_0) {
    if(std::string(arg_0).substr( std::string(arg_0).length() - 3 ) == "ase") {
        std::cout << "ASE Version - Waiting for ase_ready file to be available" << std::endl;
        std::string path = std::string(getenv("ASE_WORKDIR")) + std::string("/.ase_ready.pid");
        while (!is_file_exist(path.c_str()));
    }
}

class TSPrint {
    private:
        std::stringstream sstream;
    public:
        template<typename T>
        TSPrint& operator<<(T const& value) {
            this->sstream << value;
            
            if (value == std::endl) {
                std::cout << this->sstream.str();
                this->sstream.clear();
            }
        }
};

inline void splitFilename(const std::string& str, std::string& path, std::string &file) {
    size_t found;
    found=str.find_last_of("/\\");
    path = str.substr(0,found) + "/";
    file = str.substr(found+1);
}

inline std::vector<int> readMemoFile(std::string& path, std::string &name) {
    std::vector<int> memo_vtx;

    std::ifstream file(path + "start_vtx/" + name + "_memo");
    int count;
    file >> count;

    for (int i = 0; i < count; i++) {
        int tmp;
        file >> tmp;
        memo_vtx.push_back(tmp);
        file.ignore(10000000, '\n');
    }

    return memo_vtx;
}

#endif