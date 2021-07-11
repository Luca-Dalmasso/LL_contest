#!/usr/bin/tclsh
#command to be used within PrimeTime

suppress_message NED-045
suppress_message PTE-139
suppress_message LNK-041
suppress_message PWR-246
suppress_message PWR-602
suppress_message PWR-601

#return a percentages of cells used in the design, like the report_threshold_voltage_group
#RETURN [list "xx.yy%" "xx.yy%"], first real is for LVT% second for HVT%
#INFO: report_threshold_volatge_group command (from PrimeTime) may be necessary to be run before(??)
proc get_design_percentage {} {
	set count_LVT 0
	set tot_count 0
	set ret [list]
	foreach_in_collection cell [get_cells] {
		set group [get_attribute [get_lib_cell -of_object $cell] threshold_voltage_group]
		if {$group == "LVT"} {
			incr count_LVT
		}
		incr tot_count
	}
	set percentage [expr {$count_LVT*100.00/$tot_count}]
	lappend ret $percentage
	lappend ret [expr {100-$percentage}]
	return $ret
}

#return list of all cells (full names (ex: "U310")) that are mapping loaded design
#RETURN: [list "<full_name> <full_name> <full..."]
proc get_all_cells {} {
	set cells [list]
	foreach_in_collection cell [get_cells] {
		lappend cells [get_attribute $cell full_name]
	}
	return $cells
}

#return mapped design's 1)leakage power, 2)dynamic power, 3)total_power, 4)area
#RETURN: [list <leakage> <dynamic> <total> <area>]
#INFO: dynamic power = internal power + switching power
proc get_power_stats {} {
	set area 0
	set leakage 0
	set dynamic 0
	set total 0
	foreach cell [get_all_cells] {
		set cell_attr [get_cell_attributes $cell]
		set area [expr {$area+ [lindex $cell_attr 2] }]
		set leakage [expr {$leakage+ [lindex $cell_attr 4] }]
		set dynamic [expr {$dynamic+ [lindex $cell_attr 5] }]
		set total [expr {$total+ [lindex $cell_attr 6] }]
	}
	set ret [list]
	lappend ret $leakage
	lappend ret $dynamic
	lappend ret $total
	lappend ret $area
	return $ret
}

#scripts that retrieve all useful attributes from a cell
#USAGE: (example) get_cell_attributes "U310"
#RETURN: [list <full_name> <ref_name> <area> <size> <leak_pw> <dyn_pw> <tot_pw> <arrival> <slack>]
proc max {val1 val2} {
	if {$val1 > $val2 } {
		return $val1
	}
	return $val2
}
proc min {val1 val2} {
	if {$val1 < $val2 } {
		return $val1
	}
	return $val2
}
proc get_cell_attributes {cell_name} {
	set cellOBJ [get_cell $cell_name]
	set attr_list [list]
	if {$cellOBJ == ""} {
		puts "$cellOBJ doesn't exists in the current design!"
		return attr_list
	}
	set sizeregexp {\w*X(\d*)}
	set out_pins [get_pins -of_object $cellOBJ -filter {direction==out}]
	lappend attr_list [get_attribute $cellOBJ full_name]
	lappend attr_list [get_attribute $cellOBJ ref_name]
	lappend attr_list [get_attribute $cellOBJ area]
	set ref_name [lindex $attr_list 1]
	if {[regexp $sizeregexp $ref_name match_line size] } {
		lappend attr_list $size
	} else {
		lappend attr_list " "
	}
	lappend attr_list [get_attribute $cellOBJ leakage_power]
        lappend attr_list [get_attribute $cellOBJ dynamic_power]
	lappend attr_list [get_attribute $cellOBJ total_power]
	set max_fall_arrival 0
	set max_rise_arrival 0
	set max_slack 0
	foreach out_pin $out_pins {
		if {$max_fall_arrival==0} {
			set max_fall_arrival [get_attribute $out_pin max_fall_arrival]

		} else {
			set max_fall_arrival [max $max_fall_arrival  [get_attribute $out_pin max_fall_arrival]]
		}

		if {$max_rise_arrival==0} {
			set max_rise_arrival [get_attribute $out_pin max_rise_arrival]

		} else {
			set max_rise_arrival [max $max_rise_arrival  [get_attribute $out_pin max_rise_arrival]]
		}

		if {$max_slack==0} {
			set max_slack [get_attribute $out_pin max_slack]
		} else {
			set max_slack [min $max_slack [get_attribute $out_pin max_slack]]
		}
	}
	lappend attr_list [max $max_rise_arrival $max_fall_arrival]
	lappend attr_list $max_slack
	return $attr_list
}

#print statistics
proc print {} {
	puts "CURRENT MAPPING"
	puts "-------------------------------------------------------------------------------------------"
	set curr_stats [get_power_stats]
        set mapping [get_design_percentage]
	echo [format "%-5s | %-5s | %20s | %20s | %20s | %5s |" "HVT%" "LVT%" "LEAK" "DYNAMIC" "TOTAL" "AREA" ]
	echo [format "%-5s | %-5s | %20s | %20s | %20s | %5s |" [format %.2f [lindex $mapping 1]]  [format %.2f [lindex $mapping 0]] [lindex $curr_stats 0] [lindex $curr_stats 1] [lindex $curr_stats 2] [lindex $curr_stats 3] [lindex $curr_stats 4]]
	puts "-------------------------------------------------------------------------------------------"
	puts "final slack: [get_attribute [get_timing_paths] slack]"
}
