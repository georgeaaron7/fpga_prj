# constraints.xdc
# Constraints for epileptic seizure detection system on Xilinx Artix-7

# Clock constraint
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# Reset signal
set_property PACKAGE_PIN N17 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# System ready output - Connect to LED
set_property PACKAGE_PIN H5 [get_ports system_ready]
set_property IOSTANDARD LVCMOS33 [get_ports system_ready]

# Seizure detection result - Connect to LED
set_property PACKAGE_PIN J5 [get_ports seizure_detected]
set_property IOSTANDARD LVCMOS33 [get_ports seizure_detected]

# Result valid signal - Connect to LED
set_property PACKAGE_PIN T9 [get_ports result_valid]
set_property IOSTANDARD LVCMOS33 [get_ports result_valid]

# System status - Connect to LEDs
set_property PACKAGE_PIN T10 [get_ports {system_status[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {system_status[0]}]
set_property PACKAGE_PIN T8 [get_ports {system_status[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {system_status[1]}]

# Timing constraints
set_false_path -from [get_ports rst_n]

# Implementation hints to help timing closure
set_max_delay -from [get_cells */knn_classifier_inst/distances*] -to [get_cells */knn_classifier_inst/sorted_indices*] 9.0
set_max_delay -from [get_cells */knn_classifier_inst/ref_sorted_labels*] -to [get_cells */knn_classifier_inst/seizure_count*] 8.0

# Area constraints
create_pblock pblock_knn
add_cells_to_pblock [get_pblocks pblock_knn] [get_cells */knn_classifier_inst]
resize_pblock [get_pblocks pblock_knn] -add {SLICE_X0Y0:SLICE_X100Y150}