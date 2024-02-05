onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /diparity_generator_tb/DUT/r_current_state
add wave -noupdate -expand /diparity_generator_tb/DUT/r_sum_block
add wave -noupdate -expand -group links -expand /diparity_generator_tb/DUT/r_current_left_block
add wave -noupdate -expand -group links /diparity_generator_tb/DUT/r_current_block_left
add wave -noupdate -expand -group links /diparity_generator_tb/DUT/r_current_matrix_write_column_left
add wave -noupdate -expand -group links /diparity_generator_tb/DUT/r_current_matrix_read_column_left
add wave -noupdate -expand -group links /diparity_generator_tb/DUT/r_current_matrix_write_row_left
add wave -noupdate -expand -group links /diparity_generator_tb/DUT/r_current_matrix_read_row_left
add wave -noupdate -expand -group rechts -radix unsigned /diparity_generator_tb/DUT/w_cache_right_q
add wave -noupdate -expand -group rechts -expand /diparity_generator_tb/DUT/r_current_right_block
add wave -noupdate -expand -group rechts /diparity_generator_tb/DUT/r_current_block_right
add wave -noupdate -expand -group rechts /diparity_generator_tb/DUT/r_current_matrix_write_column_right
add wave -noupdate -expand -group rechts /diparity_generator_tb/DUT/r_current_matrix_write_row_right
add wave -noupdate -expand -group rechts /diparity_generator_tb/DUT/r_current_matrix_read_column_right
add wave -noupdate -expand -group rechts /diparity_generator_tb/DUT/r_current_matrix_read_row_right
add wave -noupdate /diparity_generator_tb/DUT/w_current_sum_of_absolute_differences
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {64396440 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 378
configure wave -valuecolwidth 150
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {64264860 ps} {64674060 ps}
bookmark add wave bookmark0 {{64009807 ps} {64115667 ps}} 0
