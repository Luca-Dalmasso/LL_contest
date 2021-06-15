# LL_contest
Low Power project for Synthesis and Optimization of Digital Systems.
Optimization procedure for DualVth std_cells design, to be used within PrimeTime.

## SETUP (WORK_SYNTHESIS environment)
[PrimeTime synthesis script](./syn/pt_synthesis/pt_analysis.tcl) <br>
**Should go**: ~/WORK_SYNTHESIS/scripts <br>
**Dependences**: power_features.tcl, synopsys_pt.setup <br> <br>
[DC compiler synthesis script](./syn/dc_synthesis/synthesis.tcl) <br>
**Should go**: ~/WORK_SYNTHESIS/scripts <br>
**Dependences**: power_features.tcl, synopsys_dc.setup <br> <br>
[DC setup script](./syn/synopsys_dc.setup) <br>
**Should go**: ~/WORK_SYNTHESIS/tech/STcmos65/ <br> <br>
[PT setup script](./syn/synopsys_pt.setup) <br>
**Should go**: ~/WORK_SYNTHESIS/tech/STcmos65/ <br> <br>
[DualVth enable script](./syn/power_features.tcl)
**Should go**: ~/WORK_SYNTHESIS/scripts
<br>
<br>
## RTL (combinatorial)
Sythesis scripts are working on C1908 netlist, change block name attribute inside pt_analysis.tcl and synthesis.tcl if y want to test another netlist. <br> <br>
[c432 struct](./syn/rtl_tested/c432/verilog/c432.v) <br>
[c1908 struct](./syn/rtl_tested/c1908/verilog/c1908.v) <br>
[c5315 struct](./syn/rtl_tested/c5315/verilog/c5315.v) <br>
**Should go**: ~/WORK_SYNTHESIS/rtl <br> <br>
[main script](./low_power.tcl)<br>