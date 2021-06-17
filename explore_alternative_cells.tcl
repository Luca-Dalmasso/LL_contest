#!/usr/bin/tclsh

#DEPENDENCES: ./myScripts/mapping_info.tcl
#IN: cell name ex U300

proc cell_resizing {cell} {
	set LVT "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/"
	set HVT "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/"
	set cell_obj [get_cell $cell]
	set VTH [lindex [lindex [get_mapping $cell] 0] 1]
	set refName [lindex [sub_min $cell_obj] 3]
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

proc sub_min {cell_name} {
	set cell_obj [get_cell $cell_name]
	set min_size 10000000000000
	set cell_min ""
	set return_list [list]
	set alt_list [get_alternative_lib_cells -current_library $cell_obj]
	if {[llength $alt_list] > 0} {
		foreach c $alt_list {
			set idx 0
			foreach bname [get_attribute $c base_name] {
				set match_flag [regexp {X(\d+)} $bname match_line size]
				if {$match_flag == 1} {
					if {$min_size == 0} {
						set min_size $size
					} elseif {$size < $min_size}  {
						set min_size $size
						set cell_min_ref_name $bname
						lset return_list 0 [lindex [get_attribute $c area] $idx]
						lset return_list 1 [lindex [get_attribute $c leakage_power] $idx]
						lset return_list 2 [lindex [get_attribute $c dynamic_power] $idx]
						lset return_list 3 $bname
					}
				}
				incr idx
			}
		}
		puts "cell_obj: $cell_name changed with $cell_min_ref_name"
	}
	return $return_list
}
