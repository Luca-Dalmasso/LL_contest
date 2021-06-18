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
	set cell_obj [get_cell $cell_name]
	set refName [sub_min $cell_obj]
	if {$refName == ""} {
		return 0
	}
	swap_cells_HVT $cell_name $refName
	return 1
}

proc swap_cells_LVT {cell_name cell_ref} {
	set LVT "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
	set cell_obj [get_cell $cell_name]
	size_cell $cell_obj "$LVT$cell_ref"
#	puts "cell_obj: [get_attribute $cell_obj ref_name] changed with $cell_ref"
	return 1
}

proc swap_cells_HVT {cell_name cell_ref} {
	set LVT "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	set cell_obj [get_cell $cell_name]
	size_cell $cell_obj "$LVT$cell_ref"
#	puts "cell_obj: [get_attribute $cell_obj ref_name] changed with $cell_ref"
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
