
# Entity: DISPARITY_GENERATOR 
- **File**: disparity_generator.vhd

## Diagram
![Diagram](DISPARITY_GENERATOR.svg "Diagram")
## Generics

| Generic name           | Type    | Value | Description |
| ---------------------- | ------- | ----- | ----------- |
| G_IMAGE_WIDTH          | integer | 640   |             |
| G_IMAGE_HEIGHT         | integer | 480   |             |
| G_BLOCK_SIZE           | integer | 8     |             |
| G_MINIMAL_DISPARITY    | integer | 0     |             |
| G_MAXIMUM_DISPARITY    | integer | 9999  |             |
| G_BACKGROUND_THRESHOLD | integer | 256   |             |
| G_MAX_SAD              | integer | 1000  |             |

## Ports

| Port name               | Direction | Type                         | Description                               |
| ----------------------- | --------- | ---------------------------- | ----------------------------------------- |
| I_CLOCK                 | in        | std_logic                    |                                           |
| I_RESET_N               | in        | std_logic                    |                                           |
| I_WRITE_ENABLE          | in        | std_logic                    |                                           |
| I_PIXEL                 | in        | std_logic_vector(9 downto 0) | SIGNED input pixel                        |
| O_READY                 | out       | std_logic                    | High when the current processing is done. |
| O_DISPARITY_PIXEL       | out       | std_logic_vector(7 downto 0) |                                           |
| O_DISPARITY_PIXEL_VALID | out       | std_logic                    |                                           |

## Signals

| Name                                  | Type                                                                                  | Description |
| ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| w_next_state                          | t_states                                                                              |             |
| r_current_state                       | t_states                                                                              |             |
| r_current_left_block                  | t_pixel_block                                                                         |             |
| r_current_right_block                 | t_pixel_block                                                                         |             |
| r_sum_block                           | t_pixel_block                                                                         |             |
| r_background_detected                 | std_logic                                                                             |             |
| r_read_pointer_left                   | std_logic_vector(12 downto 0)                                                         |             |
| r_read_pointer_right                  | std_logic_vector(12 downto 0)                                                         |             |
| w_read_pointer_left                   | std_logic_vector(12 downto 0)                                                         |             |
| w_read_pointer_right                  | std_logic_vector(12 downto 0)                                                         |             |
| r_write_pointer_left                  | std_logic_vector(12 downto 0)                                                         |             |
| r_write_pointer_right                 | std_logic_vector(12 downto 0)                                                         |             |
| w_write_pointer_left                  | std_logic_vector(12 downto 0)                                                         |             |
| w_write_pointer_right                 | std_logic_vector(12 downto 0)                                                         |             |
| w_cache_left_q                        | std_logic_vector(9 downto 0)                                                          |             |
| w_cache_right_q                       | std_logic_vector(9 downto 0)                                                          |             |
| r_cache_right_q                       | std_logic_vector(9 downto 0)                                                          |             |
| w_we_cache_left                       | std_logic                                                                             |             |
| w_we_cache_right                      | std_logic                                                                             |             |
| r_we_cache                            | std_logic                                                                             |             |
| r_pixel                               | std_logic_vector(9 downto 0)                                                          |             |
| w_cache_left_in                       | std_logic_vector(9 downto 0)                                                          |             |
| w_cache_right_in                      | std_logic_vector(9 downto 0)                                                          |             |
| r_disparity_valid                     | std_logic                                                                             |             |
| w_ready                               | std_logic                                                                             |             |
| r_current_write_col_right             | integer range 0 to G_IMAGE_WIDTH                                                      |             |
| r_current_write_row_right             | integer range 0 to G_BLOCK_SIZE                                                       |             |
| r_current_write_row_left              | integer range 0 to G_BLOCK_SIZE                                                       |             |
| r_current_block_left                  | integer range 0 to 9999999                                                            |             |
| r_current_matrix_write_column_left    | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_write_row_left       | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_read_column_left     | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_read_row_left        | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_matrix_counter_enable               | std_logic                                                                             |             |
| r_current_matrix_write_column_right   | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_write_row_right      | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_read_column_right    | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_read_row_right       | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_sum_left                    | integer range -999 * G_BLOCK_SIZE * G_BLOCK_SIZE to 999 * G_BLOCK_SIZE * G_BLOCK_SIZE |             |
| r_current_block_right                 | integer range 0 to c_right_block_amount                                               |             |
| r_current_sum_right                   | integer range 0 to 255 * G_BLOCK_SIZE * G_BLOCK_SIZE                                  |             |
| r_current_matrix_column               | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_matrix_row                  | integer range 0 to G_BLOCK_SIZE - 1                                                   |             |
| r_current_disparity                   | integer range 0 to 999999999                                                          |             |
| r_current_sad                         | integer range 0 to 9999999                                                            |             |
| r_current_difference                  | integer range -10000 to 10000                                                         |             |
| r_current_lowest_sad                  | integer range 0 to 999999999                                                          |             |
| w_current_sum_of_absolute_differences | integer range 0 to 99999999                                                           |             |
| r_write_enable                        | std_logic                                                                             |             |
| r_in_pixel                            | std_logic_vector(9 downto 0)                                                          |             |
| w_oc_ram_address_left                 | std_logic_vector(12 downto 0)                                                         |             |
| w_oc_ram_address_right                | std_logic_vector(12 downto 0)                                                         |             |

## Constants

| Name                   | Type    | Value                                                    | Description                                                                                                             |
| ---------------------- | ------- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| c_row_write_amount     | integer | G_IMAGE_WIDTH * G_BLOCK_SIZE - 1                         | The number of words to read is as big as the row width * block size                                                     |
| c_left_block_amount    | integer | integer(floor(real(G_IMAGE_WIDTH) / real(G_BLOCK_SIZE))) | The amount of blocks to process on the left                                                                             |
| c_right_block_amount   | integer | G_IMAGE_WIDTH - G_BLOCK_SIZE + 1                         | The amount of blocks to process on the right                                                                            |
| c_pixel_amount         | integer | G_IMAGE_WIDTH * G_BLOCK_SIZE                             | Total amount of pixels of the current block row.                                                                        |
| c_base_sad             | integer | 2 * 255 * G_BLOCK_SIZE * G_BLOCK_SIZE + 1                | Value to use as reset value for sum of all differences. It has to be very high because we are searching for low values. |
| c_background_threshold | integer | G_BACKGROUND_THRESHOLD * G_BLOCK_SIZE * G_BLOCK_SIZE     |                                                                                                                         |

## Types

| Name          | Type                                                                                                                                                                                                                                                                     | Description |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- |
| t_states      | ( IDLE,<br><span style="padding-left:20px"> STORE_LEFT,<br><span style="padding-left:20px"> STORE_RIGHT,<br><span style="padding-left:20px"> LOAD_LEFT_BLOCK,<br><span style="padding-left:20px"> LOAD_RIGHT_BLOCK,<br><span style="padding-left:20px"> COMPARE_BLOCKS ) |             |
| t_pixel_block |                                                                                                                                                                                                                                                                          |             |

## Processes
- PROC_STATE_MACHINE_OUT: ( r_write_enable, r_background_detected, r_current_block_left, r_current_matrix_write_column_right, r_current_matrix_write_row_right, r_current_matrix_write_row_left, r_current_matrix_write_column_left, r_write_pointer_right, r_current_block_right, r_current_block_left, r_current_state, I_WRITE_ENABLE, r_write_pointer_left, r_current_write_col_right, r_current_write_row_right, r_read_pointer_left, r_read_pointer_right, w_we_cache_right, w_we_cache_left )
- PROC_STATE_FF: ( I_RESET_N, I_CLOCK )

## Instantiations

- ROW_CACHE_LEFT_IMAGE: OC_RAM
- ROW_CACHE_RIGHT_IMAGE: OC_RAM

## State machines

![Diagram_state_machine_0]( fsm_DISPARITY_GENERATOR_00.svg "Diagram")