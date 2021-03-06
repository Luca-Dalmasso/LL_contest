#!/usr/bin/tclsh
#command to be used within PrimeTime

suppress_message NED-045
suppress_message PTE-139
suppress_message LNK-041
suppress_message PWR-246
suppress_message PWR-602
suppress_message PWR-601

#procedure to swap set of cells from HVT->LVT or LVT->HVT
#USAGE: (example1) swap "U310" LVT, (example2) swap [list "U310 U308"] HVT
#RETURN: 0->error, 1->all good
proc swap {cells type} {
	set LVT "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
	set HVT "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	if {$type!="HVT" && $type!="LVT"} {
		puts "type: $type must be HVT or LVT"
		return 0
	}
	foreach cell_name $cells {
		set cell [get_cell $cell_name]
		set refName [get_attribute $cell ref_name]
		#if i want to substitute a HVT with LVT i just need to substitute the 'LH'
		#in the cell refName with 'LL', viceversa for the LVT->HVT substitution
		if {$type=="LVT"} {
			if {[regexp {_LL} $refName] } {
				continue
			}
			set refName [regsub -all {_LH} $refName {_LL}]
			size_cell $cell "$LVT$refName"
		} else {
			if {[regexp {_LH} $refName] } {
				continue
			}
			set refName [regsub -all {_LL} $refName {_LH}]
			size_cell $cell "$HVT$refName"
		}
	}
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

#return boolean value if slack constraints are met!
#RETURN: 1->constraints met, 0->constrains not met
#INFO: WARNING: this function is time consuming!
proc get_slack {slack_inferior_limit} {
	set slack [get_attribute [get_timing_paths] slack]
	puts "circuit slack: $slack"
	if {$slack<$slack_inferior_limit} {
		return 0
	}
	return 1
}

#IN: list of cells
#OUT: list of {mapped cell name (ref_name), Threashold voltage group}
proc get_mapping {cells} {
	set cell_GTh [list]
	foreach item $cells {
		set cell [get_cell $item]
		set name [get_attribute $cell ref_name]
		set group [get_attribute [get_lib_cell -of_object $cell] threshold_voltage_group]
		lappend cell_GTh "$name $group"
	}
	return $cell_GTh
}

#IN: cell name ex U300
#OUT: cell_type (HVT,LVT)
proc swap_cell_with_min_size {cell_name} {
	set LVT "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
	set HVT "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	set cell_obj [get_cell $cell_name]
	set refName [sub_min $cell_obj]
	if {$refName == ""} {
		return 0
	}
	set VTH [lindex [lindex [get_mapping $cell_name] 0] 1]
	if {$VTH == "LVT"} {
		size_cell $cell_obj "$LVT$refName"
	} elseif {$VTH == "HVT"} {
		size_cell $cell_obj "$HVT$refName"
	} else {
		puts "VTH TYPE $VTH not recognized"
		return 0
	}
	return $VTH
}

#IN: cell_name ex U300, cell_ref_name and cell_type (HVT,LVT)
proc swap_cell_back_with_type {current_cell_name new_cell_ref new_cell_type} {
	set LVT "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
	set HVT "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	set cell_obj [get_cell $current_cell_name]
	if {$new_cell_type == "LVT"} {
		size_cell $cell_obj "$LVT$new_cell_ref"
	} elseif {$new_cell_type == "HVT"} {
		size_cell $cell_obj "$HVT$new_cell_ref"
	} else {
		puts "VTH TYPE $new_cell_type not recognized"
		return 0
	}
	return 1
}

#return minimum area substitute for IN cell
proc sub_min {cell_obj} {
	set min_size 10000000000000
	set cell_min_ref_name ""
	set bname_list [get_alternative_lib_cells -current_library -base_name $cell_obj]
	if {[llength $bname_list] > 0} {
		foreach bname $bname_list {
			set match_flag [regexp {X(\d+)} $bname match_line size]
			if {$match_flag == 1} {
				if {$min_size == 0} {
					set min_size $size
				} elseif {$size < $min_size}  {
					set min_size $size
					set cell_min_ref_name $bname
				}
			}
		}
	}
	return $cell_min_ref_name
}

#return priority list of cells to change from LVT->HVT in order to optimize the leakage power 
#	without violating slack constraints
#RETURN: cells full_names sorted by priority
#INFO: this is going to be the first function to be called
#      after this call, all the design is mapped with LVT cells
proc get_design_priority {} {
	set cell_priority 0
	set cell_hvt_leak [list]
	set cell_lvt_leak [list]
	set cell_hvt_delay [list]
	set cell_lvt_delay [list]
	set cell_init_area [list]
	set cell_min_area [list]
	set cell_init_leak [list]
	set cell_min_leak [list]
	set cell_init_dynamic [list]
	set cell_min_dynamic [list]
	set cell_init_delay [list]
	set cell_min_delay [list]
	set priority_list [list]
	set cells [get_all_cells]
	set cell_original_ref_name [list]
	set cell_original_type [list]

	#set initial params
	foreach cell $cells {
		set attributes [get_cell_attributes $cell]
		lappend cell_init_area [lindex $attributes 2]
		lappend cell_init_leak [lindex $attributes 4]
		lappend cell_init_dynamic [lindex $attributes 5]
		lappend cell_init_delay [lindex $attributes 7]
		lappend cell_original_ref_name [lindex $attributes 1]
	}

	#map all design with min-area cells
	foreach cell $cells {
		lappend cell_original_type [swap_cell_with_min_size $cell]
	}

	#set min area params
	foreach cell $cells {
		set min_a_attributes [get_cell_attributes $cell]
		lappend cell_min_area [lindex $min_a_attributes 2]
		lappend cell_min_leak [lindex $min_a_attributes 4]
		lappend cell_min_dynamic [lindex $min_a_attributes 5]
		lappend cell_min_delay [lindex $min_a_attributes 7]
	}

	set area_ratio_list [list]
	for {set i 0} {$i<[llength $cells]} {incr i} {
		if {[lindex $cell_min_area $i] == [lindex $cell_init_area $i]} {
			#no swap has been performed
			continue
		}
		set ratio "[expr ([lindex $cell_init_area $i]/[lindex $cell_min_area $i] + [lindex $cell_init_leak $i]/[lindex $cell_min_leak $i] + [lindex $cell_init_dynamic $i]/[lindex $cell_min_dynamic $i]) / ([lindex $cell_min_delay $i]/[lindex $cell_init_delay $i])]"
		puts "Ratio: $ratio"
		if {$ratio > 1} {
			#it is worth to change
			lappend area_ratio_list "[lindex $cells $i] $ratio"
		}
	}

	#map all design with min-area cells
	set i 0
	foreach cell $cells {
		swap_cell_back_with_type $cell [lindex $cell_original_ref_name $i] [lindex $cell_original_type $i]
		incr i
	}


	#map all design with HVT
	swap $cells HVT
	foreach cell $cells {
		set attributes [get_cell_attributes $cell]
		lappend cell_hvt_leak [lindex $attributes 4]
		lappend cell_hvt_delay [lindex $attributes 7]
	}

	#map all design with LVT
	swap $cells LVT
	foreach cell $cells {
		set attributes [get_cell_attributes $cell]
		lappend cell_lvt_leak [lindex $attributes 4]
		lappend cell_lvt_delay [lindex $attributes 7]
	}
	for {set i 0} {$i<[llength $cells]} {incr i} {
		set cell_priority [expr {([lindex $cell_hvt_leak $i] - [lindex $cell_lvt_leak $i])/([lindex $cell_hvt_delay $i]-[lindex $cell_lvt_delay $i])}]
		lappend priority_list "[lindex $cells $i] $cell_priority"
	}
	#area list sorted by cost function
	set ret_1 [list]
	foreach item [lsort -index 1 -decreasing -real $area_ratio_list] {
		lappend ret_1 [lindex $item 0]
	}
	#vth list sorted by cost function
	set ret_2 [list]
	foreach item [lsort -index 1 -decreasing -real $priority_list] {
		lappend ret_2 [lindex $item 0]
	}
	return [list $ret_1 $ret_2]
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
}

#optimization procedure
#INFO: MAIN function!
proc optimize {minimum_slack} {
	print
	set start_time [clock seconds]
	set curr_stats [get_power_stats]
	set linit [list [lindex $curr_stats 0] [lindex $curr_stats 1] [lindex $curr_stats 3]]
	set priorities [get_design_priority]
	set priorities_area [lindex $priorities 0]
	set priorities_vth [lindex $priorities 1]

	if {1} {
	set area_changes 0
	foreach cell $priorities_area {
		set original_ref_name [lindex [get_cell_attributes $cell] 1]
		set original_type [swap_cell_with_min_size $cell]
		incr area_changes
		if {[get_slack $minimum_slack]==0} {
			#constraints not met! rollback and stop!
			puts "NO MORE OPTIMIZATION IS POSSIBLE!"
			puts "I ARRIVED UNTIL $cell"
			#come back to the original size
			puts "change back cell $cell, with $original_ref_name"
			swap_cell_back_with_type $cell $original_ref_name $original_type
			set area_changes [expr $area_changes - 1]
			break
		}
	}
	puts "changed $area_changes cells"
	}
	foreach cell $priorities_vth {
		swap $cell HVT
		if {[get_slack $minimum_slack]==0} {
			#constraints not met! rollback and stop!
			puts "NO MORE OPTIMIZATION IS POSSIBLE!"
			puts "I ARRIVED UNTIL $cell"
			swap $cell LVT
			break
		}
	}
	puts "final slack: "
	get_slack $minimum_slack
	set end_time [clock seconds]
	print
	set curr_stats [get_power_stats]
	set lfin [list [lindex $curr_stats 0] [lindex $curr_stats 1] [lindex $curr_stats 3]]
	echo "score: [expr ((([lindex $linit 0]/[lindex $lfin 0]) + ([lindex $linit 1]/[lindex $lfin 1]) + ([lindex $linit 2]/[lindex $lfin 2])) * (1 - (($end_time - $start_time) / 900)))]"
}
