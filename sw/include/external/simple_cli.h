#pragma once
#ifndef simple_cli_def
#define simple_cli_def


#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <typeinfo>

namespace scli {
    using namespace std;

    enum param_type_e {
        POSITIONAL,
        FLAG,
        OPTION
    };

    struct param_t {
        param_type_e type;
        string name;
        string pattern;

        string description;

        bool found;
        string value;

    };

    class CLI {

    private:
        string program_name;
        string program_command;
        string program_desc;
        
        vector<param_t*> positionals;
        map<string, param_t*> params_by_name;
        map<string, param_t*> params_by_pattern;
        
        bool was_parsed;
        bool error_occured;
        
        static string StripPattern(string pattern) {
            if (pattern.size() == 0) return pattern;
            
            while (pattern.at(0) == '-'){
                pattern.erase(0, 1);
                if (pattern.size() == 0) break;
            }
            return pattern;
        };
        
        static void SplitAtEqual(string str, string& pattern, string& value) {
            value = "";
            int index = str.find("=");
            if (index == string::npos) return;
            else {
                pattern = str.substr(0, index);
                value = str.substr(index + 1);
            }
        };
        
        
    public:
        CLI(){
            was_parsed = false;
            error_occured = false; 
        };
        CLI(string program_name, string program_command, string program_desc):program_name(program_name), program_command(program_command), program_desc(program_desc){
            was_parsed = false;
            error_occured = false; 
        };

        static param_t* MakeParam(param_type_e type, string name, string pattern, string description="") {
            param_t* param = new param_t();
            
            param->type = type;
            param->name = name;
            param->pattern = StripPattern(pattern);
            param->description = description;
            param->found = false;
            param->value = "";

            return param;
        };
        
        void parse(int argc, char* argv[]){
            this->was_parsed = true;

            if (argc > 1 && (string(argv[1]) == "-h" || string(argv[1]) == "-help" || string(argv[1]) == "--help")) {
                cout << this->genHelp() << endl;
                exit(1);
            }

            for (int i = 1; i < argc; i++) {
                if (i - 1 < this->positionals.size()) {
                    this->positionals[i - 1]->found = true;
                    this->positionals[i - 1]->value = string(argv[i]);
                }
                else {
                    string value = "";
                    string pattern = string(argv[i]);
                    SplitAtEqual(pattern, pattern, value);
                    pattern = StripPattern(pattern);
                    
                    if (this->params_by_pattern.count(pattern)) {
                        param_t* param = this->params_by_pattern[pattern];
                        param->found = true;
                        
                        if (param->type == OPTION) {
                            if (value.size() > 0) param->value = value;
                            else {
                                if (i < argc - 1) {
                                    i += 1;
                                    param->value = string(argv[i]);
                                } else {
                                    error_occured = true;
                                }
                            }
                        } else {
                            if (value.size() > 0) error_occured = true;
                        }
                    } else {
                        error_occured = true;
                    }
                }
            }
        };
        
        string genHelp() {
            string help_str = "";

            //Title
            help_str += this->program_name + " - " + this->program_desc + "\n";
            
            //Usage
            help_str += "\t USAGE: " + this->program_command + " ";

            for (int i = 0; i < this->positionals.size(); i++) {
                help_str += "[" + this->positionals[i]->name + "] ";
            }

            help_str += "<options>\n";

            help_str += "\nOptions:\n";

            for (auto const& it: this->params_by_name) {  
                if (it.second->type == OPTION) {
                    help_str += "\t-" + it.second->pattern + " [value]" + "\t- " + it.second->name + " : " + it.second->description + "\n";
                }
            }

             help_str += "\nFlags:\n";
            for (auto const& it: this->params_by_name) {
                if (it.second->type == FLAG) {
                    help_str += "\t-" + it.second->pattern + "\t- " + it.second->name + " : " + it.second->description + "\n";
                }
            }


            return help_str;
        };

        bool is(string name) {
            if (this->params_by_name.count(name) == 0) {
                this->error_occured = true;
                return false;
            }

            return this->params_by_name[name]-> found;
        }

        string operator[](string name) {
            if (this->params_by_name.count(name) == 0) {
                this->error_occured = true;
                return "";
            }

            param_t* param = this->params_by_name[name];
            if (param->type != OPTION && param->type != POSITIONAL) {
                this->error_occured = true;
                return "";
            }

            if (param->found){
                return param->value;
            } else {
                this->error_occured = true;
                return "";
            }
        }
        
        int asInt(string name) {
            if (this->params_by_name.count(name) == 0) {
                this->error_occured = true;
                return -1;
            }

            param_t* param = this->params_by_name[name];
            if (param->type != OPTION && param->type != POSITIONAL) {
                this->error_occured = true;
                return -1;
            }

            if (param->found){
                return atoi(param->value.c_str());
            } else {
                this->error_occured = true;
                return -1;
            }
        }

        double asDouble(string name) {
            if (this->params_by_name.count(name) == 0) {
                this->error_occured = true;
                return -1;
            }

            param_t* param = this->params_by_name[name];
            if (param->type != OPTION && param->type != POSITIONAL) {
                this->error_occured = true;
                return -1;
            }

            if (param->found){
                return atof(param->value.c_str());
            } else {
                this->error_occured = true;
                return -1;
            }
        }

        bool error() {
            return this->error_occured;
        }

        CLI& addPositional(string name, string description="") {
            param_t* param = MakeParam(POSITIONAL, name, "", description);
            this->positionals.push_back(param);
            this->params_by_name[name] = param;
            return *this;
        };

        CLI& addFlag(string name, string pattern, string description="") {
            param_t* param = MakeParam(FLAG, name, pattern, description);
            this->params_by_name[name] = param;
            this->params_by_pattern[param->pattern] = param;
            return *this;
        }

        
        CLI& addOption(string name, string pattern, string description="") {
            param_t* param = MakeParam(OPTION, name, pattern, description);
            this->params_by_name[name] = param;
            this->params_by_pattern[param->pattern] = param;
            return *this;
        }
    
        void error(string error_msg) {
            cout << this->genHelp() << endl;
            cout << endl << "CLI Error: " << error_msg << endl;
            exit(-1);
        }

        ~CLI(){}
    };
}


#endif