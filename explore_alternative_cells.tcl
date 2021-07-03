#!/usr/bin/tclsh

#IMPORTANT: before running this you should run: 'report_threshold_voltage_group' 
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
	return 1
}

proc swap_cell_back {current_cell_name new_cell_ref} {
	set LVT "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
	set HVT "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	set cell_obj [get_cell $current_cell_name]
	set VTH [lindex [lindex [get_mapping $current_cell_name] 0] 1]
	if {$VTH == "LVT"} {
		size_cell $cell_obj "$LVT$new_cell_ref"
	} elseif {$VTH == "HVT"} {
		size_cell $cell_obj "$HVT$new_cell_ref"
	} else {
		puts "VTH TYPE $VTH not recognized"
		return 0
	}
	return 1
}

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
