N      ?= 256
FRAMES ?= 60
RTL    := rtl/fft_core.sv
BUILD  := build

.PHONY: test lint synth clean

test:
	@mkdir -p $(BUILD)
	python3 scripts/gen_twiddle.py $(N) $(BUILD)/twiddle.hex
	python3 scripts/gen_vectors.py $(N) $(FRAMES) $(BUILD)/in.txt
	iverilog -g2012 -P tb_fft.N=$(N) -P tb_fft.TW_FILE=\"$(BUILD)/twiddle.hex\" -o $(BUILD)/tb.vvp $(RTL) tb/tb_fft.sv
	vvp -n $(BUILD)/tb.vvp +in=$(BUILD)/in.txt +out=$(BUILD)/out.txt
	python3 scripts/check.py $(N) $(BUILD)/in.txt $(BUILD)/out.txt

lint:
	cd rtl && verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC --top-module fft_core fft_core.sv

synth:
	@mkdir -p $(BUILD)
	cd rtl && yosys -q -p "read_verilog -sv fft_core.sv; synth -top fft_core; tee -o ../$(BUILD)/synth_stat.txt stat"

clean:
	rm -rf $(BUILD)
