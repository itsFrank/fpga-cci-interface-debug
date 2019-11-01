SHELL := /bin/bash 

default:
	if [[ -f './sim/work/.app_lock.pid' ]]; then rm ./sim/work/.app_lock.pid; fi
	if [[ -f './sim/work/.ase_ready.pid' ]]; then rm ./sim/work/.ase_ready.pid; fi
	cd sim; make SHELL=bash | tee ./.make_out | grep --color -E '^|Error'
	if [[ $$(cd sim; cat ./.make_out | grep 'Errors: [^0]') ]]; then echo -e "\e[31m ERROR IN VLOG \e[39m."; else cd sim; make SHELL=bash sim | grep --color -E '^|Error'; fi
vlog:
	cd sim; make SHELL=bash | grep --color -E '^|Error'

.PHONY: sim test
sim:
	if [[ -f './sim/work/.app_lock.pid' ]]; then rm ./sim/work/.app_lock.pid; fi
	if [[ -f './sim/work/.ase_ready.pid' ]]; then rm ./sim/work/.ase_ready.pid; fi
	cd sim; make SHELL=bash sim | grep --color -E '^|Error'

simsetup:
	rm -rf sim
	./setup/setup_ase sim

syncpy:
	test $(SYNCPY)
	mkdir $(SYNCPY)
	cp -r include_modules $(SYNCPY)
	cp -r rtl $(SYNCPY)
	cp -r setup $(SYNCPY)
	cp -r Makefile $(SYNCPY)

synthsetup:
	afu_synth_setup -s setup/sources.txt synth

synthsetup-seed:
	test $(SEED)
	afu_synth_setup -s setup/sources.txt synth
	sed -i 's/-name\ SEED\ 0/-name\ SEED\ $(SEED)/g' synth/build/bdw_503_pr_afu_synth.qsf

wave:
	cd sim/work; vsim -view vsim.wlf

test:
	$(eval TEST_LIST = $(shell cd test;./setup/test_list.sh))
	cd test; source ~/local/h/h.sh; runSVUnit $(TEST_LIST) -s questa -f setup/sources.f -r "-do setup/log_wave.do" -r "-L alt_lib" -c +define+TWENTYNM_MOCK -c +incdir+../rtl | grep -vE '(fp_mac|protected).*Missing connection for port' | h "Error|FAILED" PASSED "Warning|RUNNING"testsetup:
	cd test; vlib alt_lib; vlog -work alt_lib -l compile.log -f /homes/obrienfr/intel/spmat_afu/hw/test/setup/altera_base.f

clean:
	cd sim/work; make clean

log:
	if [[ -f './sim/work/.ase_ready.pid' ]]; then rm ./sim/work/.ase_ready.pid; fi
	if [[ $$(cd sim; make SHELL=bash | tee /dev/stderr | grep 'Errors: [^0]') ]]; then echo -e "\e[31m ERROR IN VLOG"; else cd sim; make sim | tee simout.log; fi

simlog:
	if [[ -f './sim/work/.ase_ready.pid' ]]; then rm ./sim/work/.ase_ready.pid; fi
	cd sim; make SHELL=bash sim | tee simout.log