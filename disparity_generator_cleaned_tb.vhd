library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;
  use ieee.std_logic_textio.all;

entity DIPARITY_GENERATOR_CLEANED_TB is -- keine Schnittstellen
end entity DIPARITY_GENERATOR_CLEANED_TB;

architecture TESTBENCH of DIPARITY_GENERATOR_CLEANED_TB is

  component DISPARITY_GENERATOR is
    generic (
      G_IMAGE_WIDTH          : integer := 640;
      G_IMAGE_HEIGHT         : integer := 480;
      G_BLOCK_SIZE           : integer := 4;
      G_MINIMAL_DISPARITY    : integer := 0;
      G_MAXIMUM_DISPARITY    : integer := 999;
      G_BACKGROUND_THRESHOLD : integer := 500
    );
    port (
      I_CLOCK                 : in    std_logic;
      I_RESET_N               : in    std_logic;
      I_WRITE_ENABLE          : in    std_logic;
      I_PIXEL                 : in    std_logic_vector(9 downto 0);

      O_READY                 : out   std_logic;
      O_DISPARITY_PIXEL       : out   std_logic_vector(7 downto 0);
      O_DISPARITY_PIXEL_VALID : out   std_logic
    );
  end component;

  component DISPARITY_GENERATOR_REVERSE is
    generic (
      G_IMAGE_WIDTH          : integer := 640;
      G_IMAGE_HEIGHT         : integer := 480;
      G_BLOCK_SIZE           : integer := 4;
      G_MINIMAL_DISPARITY    : integer := 0;
      G_MAXIMUM_DISPARITY    : integer := 999;
      G_BACKGROUND_THRESHOLD : integer := 500
    );
    port (
      I_CLOCK                 : in    std_logic;
      I_RESET_N               : in    std_logic;
      I_WRITE_ENABLE          : in    std_logic;
      I_PIXEL                 : in    std_logic_vector(9 downto 0);

      O_READY                 : out   std_logic;
      O_DISPARITY_PIXEL       : out   std_logic_vector(7 downto 0);
      O_DISPARITY_PIXEL_VALID : out   std_logic
    );
  end component;

  component VGA_OC_RAM is
    port (
      ADDRESS_A    : in    std_logic_vector(14 downto 0);
      ADDRESS_B    : in    std_logic_vector(14 downto 0);
      CLOCK_A      : in    std_logic  := '1';
      CLOCK_B      : in    std_logic;
      DATA_A       : in    std_logic_vector(7 downto 0);
      DATA_B       : in    std_logic_vector(7 downto 0);
      WREN_A       : in    std_logic  := '0';
      WREN_B       : in    std_logic  := '0';
      Q_A          : out   std_logic_vector(7 downto 0);
      Q_B          : out   std_logic_vector(7 downto 0)
    );
  end component vga_oc_ram;

  procedure discard_separator (
    variable line_pointer : inout line
  ) is

    variable dump : string(1 to 1);

  begin

    read(line_pointer, dump);

  end procedure;

  procedure get_integer (
    variable line_pointer : inout line;
    variable int_out      : out integer) is

    variable v_int_out           : integer;
    variable v_separator_discard : string(1 to 1);

  begin

    read(line_pointer, v_int_out);
    int_out := v_int_out;
    discard_separator(line_pointer);

  end procedure;

  procedure get_integer (
    variable line_pointer : inout line;
    signal int_out        : out std_logic_vector) is

    variable v_int_out           : integer;
    variable v_separator_discard : string(1 to 1);

  begin

    read(line_pointer, v_int_out);
    int_out <= std_logic_vector(to_unsigned(v_int_out, int_out'length));
    discard_separator(line_pointer);

  end procedure;

  -- Ports in Richtung nutzende Komponente
  signal clk_tb_s                                                               : std_logic;
  signal w_reset_n                                                              : std_logic;
  signal w_write_enable                                                         : std_logic;
  signal w_pixel                                                                : std_logic_vector(7 downto 0);
  signal w_disparity_lr_ready                                                   : std_logic;
  signal w_disparity_rl_ready                                                   : std_logic;
  signal w_disparity_pixel_lr                                                   : std_logic_vector(7 downto 0);
  signal w_disparity_pixel_rl                                                   : std_logic_vector(7 downto 0);
  signal w_disparity_pixel_lr_valid                                             : std_logic;
  signal w_disparity_pixel_rl_valid                                             : std_logic;

  signal r_write_enable                                                         : std_logic := '0';
  signal r_write_enable_delay                                                   : std_logic := '0';
  signal r_pixel                                                                : std_logic_vector(9 downto 0);
  signal w_disparity_in                                                         : std_logic_vector(9 downto 0);

  signal r_current_disparity_image_row_count                                    : integer := 0;

  constant c_block_size                                                         : integer := 4;
  constant c_image_width                                                        : integer := 640;
  constant c_image_height                                                       : integer := 480;
  constant c_background_threshold                                               : integer := 256;

  constant c_disparity_error_threshold                                          : integer := 20;

  constant c_disparity_width                                                    : integer := c_image_width / c_block_size;
  constant c_disparity_height                                                   : integer := c_image_height / c_block_size;
  constant c_disparity_pixel_amount                                             : integer := c_disparity_width * c_disparity_height;

  constant c_result_image_width                                                 : integer := c_image_width / c_block_size;
  constant c_result_image_height                                                : integer := c_image_height / c_block_size;

  constant c_minimal_disparity                                                  : integer := 0;
  constant c_maximum_disparity                                                  : integer := 999;

  constant c_disparity_image_2_offset                                           : integer := c_disparity_pixel_amount;

  type out_memory is ARRAY (0 to c_result_image_height - 1, 0 to c_result_image_width - 1) of integer;

  signal r_current_lr_y_offset                                                  : integer range 0 to c_disparity_pixel_amount;
  signal r_current_lr_x                                                         : integer range 0 to c_disparity_width;

  signal result_image_lr                                                        : out_memory;
  signal result_image_rl                                                        : out_memory;
  signal result_image_final                                                     : out_memory;

  -- constant c_filename_image1                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild1_inc.csv";
  -- constant c_filename_image1                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild1_inc_klein.csv";
  constant c_filename_image1                                                    : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\bild1_sw.csv";
  -- constant c_filename_image2                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild1_inc.csv";
  -- constant c_filename_image2                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild2_inc_klein.csv";
  constant c_filename_image2                                                    : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\bild2_sw.csv";
  constant c_filename_out_lr                                                    : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\disparity_lr.csv";
  constant c_filename_out_rl                                                    : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\disparity_rl.csv";
  constant c_filename_out_final                                                 : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\disparity_final.csv";

  file   fptr_lr                                                                : text;
  file   fptr_rl                                                                : text;
  file   fptr_final                                                             : text;
  signal test_int                                                               : integer;
  -- signal test_string : string(1 to 1);

  signal r_line_opened                                                          : std_logic := '0';

  signal test_string                                                            : string(1 to 1);

  type t_states is (
    CLOSE_FILE,
    WAIT_FOR_READY,
    TRANSMIT_IMAGE1,
    TRANSMIT_IMAGE2,
    LOAD_DISPARITY,

    LOAD_DISPARITY_LEFT_RIGHT,
    LOAD_DISPARITY_RIGHT_LEFT,
    WRITE_FINAL_DISPARITY_VALUE,

    PRELOAD_FIRST_READ,
    WRITE_RESULTS,
    FINISHED
  );

  signal w_next_state                                                           : t_states;
  signal r_current_state                                                        : t_states := CLOSE_FILE;

  -- Current column and of the first image to load
  -- Row 0 <= x < block_size
  -- Values get reset after each load
  signal r_image1_load_col                                                      : integer := 0;
  signal r_image1_load_row                                                      : integer := 0;

  signal r_image2_load_col                                                      : integer := 0;
  signal r_image2_load_row                                                      : integer := 0;

  signal r_current_file_write_row                                               : integer := 0;
  signal r_current_file_write_column                                            : integer := 0;

  -- Current row in the images
  signal r_image1_row_pointer                                                   : integer := 0;
  signal r_image2_row_pointer                                                   : integer := 0;

  -- Current column and row of the result image
  signal r_current_disparity_lr_image_column                                    : integer := 0;
  signal r_current_disparity_lr_image_row                                       : integer := 0;

  signal r_current_disparity_rl_image_column                                    : integer := 0;
  signal r_current_disparity_rl_image_row                                       : integer := 0;

  signal r_mean_value_left                                                      : integer range 0 to 999999999;
  signal r_mean_value_right                                                     : integer range 0 to 999999999;

  signal w_vga_ram_read_address                                                 : std_logic_vector(14 downto 0);
  signal r_vga_ram_read_address                                                 : std_logic_vector(14 downto 0) := (others => '0');
  signal r_vga_ram_write_pointer                                                : std_logic_vector(14 downto 0) := (others => '0');
  signal w_vga_ram_write_address                                                : std_logic_vector(14 downto 0) := (others => '0');
  signal r_vga_ram_write_address                                                : std_logic_vector(14 downto 0) := (others => '0');
  signal r_vga_ram_data                                                         : std_logic_vector(7 downto 0);
  signal r_vga_ram_wren                                                         : std_logic;
  signal w_vga_ram_q                                                            : std_logic_vector(7 downto 0);

  signal w_disparity_ram_read_address_a                                         : std_logic_vector(14 downto 0);
  signal r_disparity_ram_read_address_b                                         : std_logic_vector(14 downto 0);
  signal r_disparity_ram_write_pointer_a                                        : std_logic_vector(14 downto 0) := (others => '0');
  signal r_disparity_ram_write_pointer_b                                        : std_logic_vector(14 downto 0) := std_logic_vector(to_unsigned(c_disparity_pixel_amount, 15));

  signal r_disparity_ram_read_pointer_a                                         : std_logic_vector(14 downto 0) := (others => '0');
  signal r_disparity_ram_read_pointer_b                                         : std_logic_vector(14 downto 0) := (others => '0');

  signal w_disparity_ram_write_pointer_b                                        : std_logic_vector(14 downto 0) := std_logic_vector(to_unsigned(c_disparity_pixel_amount, 15));
  signal w_disparity_ram_address_a                                              : std_logic_vector(14 downto 0) := (others => '0');
  signal w_disparity_ram_address_b                                              : std_logic_vector(14 downto 0) := (others => '0');
  signal r_disparity_ram_data_a                                                 : std_logic_vector(7 downto 0);
  signal r_disparity_ram_data_b                                                 : std_logic_vector(7 downto 0);
  signal r_disparity_ram_wren_a                                                 : std_logic;
  signal r_disparity_ram_wren_b                                                 : std_logic;
  signal w_disparity_ram_q_a                                                    : std_logic_vector(7 downto 0);
  signal w_disparity_ram_q_b                                                    : std_logic_vector(7 downto 0);

  constant c_mean_left                                                          : integer := 143;
  constant c_mean_right                                                         : integer := 172;

  constant c_max_disparity_y_offset                                             : integer := (c_disparity_height - 1) * c_disparity_width;

begin

  DISPARITY : DISPARITY_GENERATOR
    port map (
      I_CLOCK        => clk_tb_s,
      I_RESET_N      => w_reset_n,
      I_WRITE_ENABLE => r_write_enable,
      I_PIXEL        => w_disparity_in,

      O_READY                 => w_disparity_lr_ready,
      O_DISPARITY_PIXEL       => w_disparity_pixel_lr,
      O_DISPARITY_PIXEL_VALID => w_disparity_pixel_lr_valid
    );

  DISPARITY_REVERSE : DISPARITY_GENERATOR_REVERSE
    port map (
      I_CLOCK        => clk_tb_s,
      I_RESET_N      => w_reset_n,
      I_WRITE_ENABLE => r_write_enable,
      I_PIXEL        => w_disparity_in,

      O_READY                 => w_disparity_rl_ready,
      O_DISPARITY_PIXEL       => w_disparity_pixel_rl,
      O_DISPARITY_PIXEL_VALID => w_disparity_pixel_rl_valid
    );

  VGA_RAM : VGA_OC_RAM
    port map (
      ADDRESS_A => r_vga_ram_read_address,
      ADDRESS_B => r_vga_ram_write_address,
      CLOCK_A   => clk_tb_s,
      CLOCK_B   => clk_tb_s,
      DATA_A    => (others => '0'),
      DATA_B    => r_vga_ram_data,
      WREN_A    => '0',
      WREN_B    => r_vga_ram_wren,
      Q_A       => w_vga_ram_q
    -- q_b    : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
    );

  DISPARITY_RAM : VGA_OC_RAM
    port map (
      ADDRESS_A => w_disparity_ram_address_a,
      ADDRESS_B => w_disparity_ram_address_b,
      CLOCK_A   => clk_tb_s,
      CLOCK_B   => clk_tb_s,
      DATA_A    => r_disparity_ram_data_a,
      DATA_B    => r_disparity_ram_data_b,
      WREN_A    => r_disparity_ram_wren_a,
      WREN_B    => r_disparity_ram_wren_b,
      Q_A       => w_disparity_ram_q_a,
      Q_B       => w_disparity_ram_q_b
    -- q_b    : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
    );

  P_CLK : process is

  begin

    clk_tb_s <= '1';
    wait for 5 ns;
    clk_tb_s <= '0';
    wait for 5 ns;

  end process P_CLK;

  PROC_STATE_OUT : process (w_disparity_ram_q_a, w_disparity_ram_q_b, r_vga_ram_write_address, r_current_lr_y_offset, r_current_lr_x, w_disparity_pixel_lr_valid, w_disparity_pixel_rl_valid, r_current_state, r_image1_load_col, r_image1_load_row, r_image2_load_col, r_image2_load_row, r_current_disparity_lr_image_column, r_current_disparity_lr_image_row, w_disparity_lr_ready, r_current_disparity_rl_image_column, r_current_disparity_rl_image_row, w_disparity_rl_ready) is

    variable v_col_count_image1 : integer := 0;
    variable v_row_count_image1 : integer := 0;

    variable v_col_count_image2 : integer := 0;
    variable v_row_count_image2 : integer := 0;
    variable v_current_cycle    : integer := 1;

    variable v_current_disparity_column : integer := 0;

    variable v_fstatus  : file_open_status;
    variable v_line_out : line;

    file image1 : text open read_mode is c_filename_image1;
    file image2 : text open read_mode is c_filename_image2;

    variable v_current_image1_line : line;
    variable v_current_image2_line : line;

  begin

    case r_current_state is

      when CLOSE_FILE =>
        w_next_state <= WAIT_FOR_READY;

        w_write_enable <= '0';
        w_pixel        <= (others => '0');

      when WAIT_FOR_READY =>

        if (w_disparity_rl_ready = '1' and w_disparity_lr_ready = '1') then
          w_next_state <= TRANSMIT_IMAGE1;
        else
          w_next_state <= WAIT_FOR_READY;
        end if;

        w_write_enable <= '0';
        w_pixel        <= (others => '0');

      -- Übertrage BLOCK_SIZE Zeilen von Bild 1
      when TRANSMIT_IMAGE1 =>

        if (r_image1_load_col = c_image_width - 1 and r_image1_load_row = c_block_size - 1) then
          w_next_state <= TRANSMIT_IMAGE2;
        else
          w_next_state <= TRANSMIT_IMAGE1;
        end if;

        w_write_enable <= '1';

      -- Übertrage BLOCK_SIZE Zeilen von Bild 2
      when TRANSMIT_IMAGE2 =>

        if (r_image2_load_col = c_image_width - 1 and r_image2_load_row = c_block_size - 1) then
          w_next_state <= LOAD_DISPARITY;
        else
          w_next_state <= TRANSMIT_IMAGE2;
        end if;

        w_write_enable <= '1';

      -- Lade Disparitätspixel
      -- Danach lade entweder nächste 2 Bilder oder speichere Datei.
      when LOAD_DISPARITY =>

        if (w_disparity_lr_ready = '1' and r_current_disparity_lr_image_row = c_disparity_height - 1 and w_disparity_rl_ready = '1' and r_current_disparity_rl_image_row = c_disparity_height - 1) then
          w_next_state <= LOAD_DISPARITY_LEFT_RIGHT;
        elsif (w_disparity_lr_ready = '1' and r_current_disparity_lr_image_row < c_disparity_height - 1 and w_disparity_rl_ready = '1' and r_current_disparity_rl_image_row < c_disparity_height - 1) then
          w_next_state <= TRANSMIT_IMAGE1;
        else
          w_next_state <= LOAD_DISPARITY;
        end if;

        w_write_enable <= '0';

      when LOAD_DISPARITY_LEFT_RIGHT =>

        w_next_state <= LOAD_DISPARITY_RIGHT_LEFT;

      when LOAD_DISPARITY_RIGHT_LEFT =>

        w_next_state <= WRITE_FINAL_DISPARITY_VALUE;

      when WRITE_FINAL_DISPARITY_VALUE =>

        if (r_current_lr_x = c_disparity_width - 1 and r_current_lr_y_offset = c_max_disparity_y_offset) then
          w_next_state <= PRELOAD_FIRST_READ;
        else
          w_next_state <= LOAD_DISPARITY_LEFT_RIGHT;
        end if;

      when PRELOAD_FIRST_READ =>
        w_next_state <= WRITE_RESULTS;

      when WRITE_RESULTS =>

        if (unsigned(r_disparity_ram_read_pointer_a) = c_disparity_pixel_amount - 1) then
          w_next_state <= FINISHED;
        else
          w_next_state <= WRITE_RESULTS;
        end if;

      when FINISHED =>
        w_write_enable <= '0';

    end case;

  end process PROC_STATE_OUT;

  PROC_STATE_FF : process (w_reset_n, clk_tb_s) is
  begin

  end process PROC_STATE_FF;

  PROC_FILE_HANDLER_IN : process (w_reset_n, clk_tb_s) is

    variable fstatus_lr  : file_open_status;
    variable line_out_lr : line;

    variable fstatus_rl  : file_open_status;
    variable line_out_rl : line;

    variable fstatus_final  : file_open_status;
    variable line_out_final : line;

    file image1 : text open read_mode is c_filename_image1;
    file image2 : text open read_mode is c_filename_image2;

    variable current_image1_line : line;
    variable current_image2_line : line;

    variable pixel_left  : std_logic_vector(7 downto 0);
    variable pixel_right : std_logic_vector(7 downto 0);

  begin

    if (w_reset_n = '0') then
      r_pixel         <= (others => '0');
      r_current_state <= WAIT_FOR_READY;
    elsif (rising_edge(clk_tb_s)) then
      r_current_state <= w_next_state;

      case r_current_state is

        when CLOSE_FILE =>
          file_close(fptr_lr);
          file_close(fptr_rl);
          file_close(fptr_final);

        when WAIT_FOR_READY =>
          file_open(fstatus_lr, fptr_lr, c_filename_out_lr, write_mode);
          file_open(fstatus_rl, fptr_rl, c_filename_out_rl, write_mode);
          file_open(fstatus_final, fptr_final, c_filename_out_final, write_mode);
          readline(image1, current_image1_line);
          readline(image2, current_image2_line);

        when TRANSMIT_IMAGE1 =>

          r_disparity_ram_wren_a <= '0';
          r_disparity_ram_wren_b <= '0';

          if (w_write_enable = '1') then
            get_integer(current_image1_line, r_pixel);

            if (r_image1_load_col < c_image_width - 1) then
              r_image1_load_col <= r_image1_load_col + 1;
            else
              r_image1_load_col <= 0;
            end if;

            if (r_image1_load_col = c_image_width - 1) then
              if (r_image1_load_row <= c_block_size - 1) then
                if (r_image1_row_pointer < c_image_height - 1) then
                  readline(image1, current_image1_line);
                end if;
                r_image1_load_row    <= r_image1_load_row + 1;
                r_image1_row_pointer <= r_image1_row_pointer + 1;
              else
                r_image1_load_row <= 0;
              end if;
            end if;
          end if;

        when TRANSMIT_IMAGE2 =>
          if (w_write_enable = '1') then
            get_integer(current_image2_line, r_pixel);

            if (r_image2_load_col < c_image_width - 1) then
              r_image2_load_col <= r_image2_load_col + 1;
            else
              r_image2_load_col <= 0;
            end if;

            if (r_image2_load_col = c_image_width - 1) then
              if (r_image2_load_row <= c_block_size - 1) then
                if (r_image2_row_pointer < c_image_height - 1) then
                  readline(image2, current_image2_line);
                end if;
                r_image2_load_row    <= r_image2_load_row + 1;
                r_image2_row_pointer <= r_image2_row_pointer + 1;
              else
                r_image2_load_row <= 0;
              end if;
            end if;
          end if;

        when LOAD_DISPARITY =>

          if (w_disparity_pixel_lr_valid = '1') then
            r_disparity_ram_wren_a <= '1';
            r_disparity_ram_data_a <= w_disparity_pixel_lr;

            if (to_integer(unsigned(r_disparity_ram_write_pointer_a)) < c_disparity_pixel_amount - 1) then
              r_disparity_ram_write_pointer_a <= std_logic_vector(unsigned(r_disparity_ram_write_pointer_a) + to_unsigned(1, r_disparity_ram_write_pointer_a'length));
            end if;

            if (r_current_disparity_lr_image_column < c_result_image_width - 1) then
              r_current_disparity_lr_image_column <= r_current_disparity_lr_image_column + 1;
            else
              r_current_disparity_lr_image_column <= 0;
            end if;

            if (r_current_disparity_lr_image_column = c_result_image_width - 1) then
              r_current_disparity_lr_image_row <= r_current_disparity_lr_image_row + 1;
            end if;
          else
            r_disparity_ram_wren_a <= '0';
          end if;

          if (w_disparity_pixel_rl_valid = '1') then
            r_disparity_ram_wren_b <= '1';
            r_disparity_ram_data_b <= w_disparity_pixel_rl;

            if (to_integer(unsigned(r_disparity_ram_write_pointer_b)) > 0) then
              r_disparity_ram_write_pointer_b <= std_logic_vector(unsigned(r_disparity_ram_write_pointer_b) - to_unsigned(1, r_disparity_ram_write_pointer_b'length));
            end if;

            if (r_current_disparity_rl_image_column < c_result_image_width - 1) then
              r_current_disparity_rl_image_column <= r_current_disparity_rl_image_column + 1;
            else
              r_current_disparity_rl_image_column <= 0;
            end if;

            if (r_current_disparity_rl_image_column = c_result_image_width - 1) then
              r_current_disparity_rl_image_row <= r_current_disparity_rl_image_row + 1;
            end if;
          else
            r_disparity_ram_wren_b <= '0';
          end if;

          if (w_next_state = PRELOAD_FIRST_READ) then
            r_disparity_ram_write_pointer_a <= (others => '0');
            r_disparity_ram_write_pointer_b <= std_logic_vector(to_unsigned(c_disparity_pixel_amount, r_disparity_ram_write_pointer_b'length));
          end if;

        when LOAD_DISPARITY_LEFT_RIGHT =>
          r_vga_ram_wren <= '0';

        when LOAD_DISPARITY_RIGHT_LEFT =>
          r_vga_ram_wren <= '0';

        when WRITE_FINAL_DISPARITY_VALUE =>
          if (r_current_lr_x < c_disparity_width - 1) then
            r_current_lr_x <= r_current_lr_x + 1;
          else
            r_current_lr_x <= 0;
          end if;

          if (r_current_lr_x = c_disparity_width - 1) then
            if (r_current_lr_y_offset < c_max_disparity_y_offset) then
              r_current_lr_y_offset <= r_current_lr_y_offset + c_disparity_width;
            else
              r_current_lr_y_offset <= 0;
            end if;
          end if;

          if (unsigned(r_vga_ram_write_address) < c_disparity_pixel_amount - 1) then
            r_vga_ram_write_address <= std_logic_vector(unsigned(r_vga_ram_write_address) + 1);
          else
            r_vga_ram_write_address <= (others => '0');
          end if;

          if (abs(to_integer(unsigned(w_disparity_ram_q_a)) - to_integer(unsigned(w_disparity_ram_q_b))) < c_disparity_error_threshold) then
            r_vga_ram_data <= w_disparity_ram_q_a;
          else
            r_vga_ram_data <= (others => '0');
          end if;

          r_vga_ram_wren <= '1';
          
          if (w_next_state = PRELOAD_FIRST_READ) then
            r_disparity_ram_write_pointer_a <= (others => '0');
            r_disparity_ram_write_pointer_b <= std_logic_vector(to_unsigned(c_disparity_pixel_amount, r_disparity_ram_write_pointer_b'length));
          end if;
          
          when PRELOAD_FIRST_READ =>
          
          r_vga_ram_wren <= '0';
          r_disparity_ram_read_pointer_a <= std_logic_vector(to_unsigned(1, r_disparity_ram_read_pointer_a'length));
          r_disparity_ram_read_pointer_b <= std_logic_vector(to_unsigned(1, r_disparity_ram_read_pointer_b'length));

        when WRITE_RESULTS =>

          write(line_out_lr, to_integer(unsigned(w_disparity_ram_q_a)));
          write(line_out_rl, to_integer(unsigned(w_disparity_ram_q_b)));
          write(line_out_final, to_integer(unsigned(w_vga_ram_q)));

          if (r_current_disparity_lr_image_column < c_image_width / c_block_size - 1) then
            write(line_out_lr, string'(","));
            write(line_out_rl, string'(","));
            write(line_out_final, string'(","));
          else
            writeline(fptr_lr, line_out_lr);
            writeline(fptr_rl, line_out_rl);
            writeline(fptr_final, line_out_final);
          end if;

          if (r_current_disparity_lr_image_column < c_result_image_width - 1) then
            r_current_disparity_lr_image_column <= r_current_disparity_lr_image_column + 1;
          else
            r_current_disparity_lr_image_column <= 0;
          end if;

          if (r_current_disparity_lr_image_column = c_result_image_width - 1) then
            r_current_disparity_lr_image_row <= r_current_disparity_lr_image_row + 1;
          end if;

          if (r_current_disparity_rl_image_column < c_result_image_width - 1) then
            r_current_disparity_rl_image_column <= r_current_disparity_rl_image_column + 1;
          else
            r_current_disparity_rl_image_column <= 0;
          end if;

          if (r_current_disparity_rl_image_column = c_result_image_width - 1) then
            r_current_disparity_rl_image_row <= r_current_disparity_rl_image_row + 1;
          end if;

          r_vga_ram_read_address <= std_logic_vector(unsigned(r_vga_ram_read_address) + 1);

          r_image1_load_col <= 0;
          r_image1_load_row <= 0;
          r_image2_load_col <= 0;
          r_image2_load_row <= 0;

          r_disparity_ram_wren_a <= '0';
          r_disparity_ram_wren_b <= '0';

          r_disparity_ram_read_pointer_a <= std_logic_vector(unsigned(r_disparity_ram_read_pointer_a) + 1);
          r_disparity_ram_read_pointer_b <= std_logic_vector(unsigned(r_disparity_ram_read_pointer_b) + 1);

        when FINISHED =>
          file_close(fptr_lr);
          file_close(fptr_rl);
          file_close(fptr_final);

      end case;

    end if;

  end process PROC_FILE_HANDLER_IN;

  PROC_WRITE_ENABLE_DELAY : process (w_reset_n, clk_tb_s) is
  begin

    if (w_reset_n = '0') then
      r_write_enable <= '0';
    elsif (rising_edge(clk_tb_s)) then
      r_write_enable <= w_write_enable;
    --   r_write_enable       <= r_write_enable_delay;
    end if;

  end process PROC_WRITE_ENABLE_DELAY;

  w_reset_n <= '1';

  w_disparity_in <= std_logic_vector(to_signed(to_integer(signed(r_pixel)), 10)) when r_current_state = TRANSMIT_IMAGE1 else
                    std_logic_vector(to_signed(to_integer(signed(r_pixel)), 10));

  w_disparity_ram_write_pointer_b <= std_logic_vector(unsigned(r_disparity_ram_write_pointer_b) + c_disparity_image_2_offset);

  w_disparity_ram_address_a <= r_disparity_ram_write_pointer_a when r_current_state = LOAD_DISPARITY else
                               r_disparity_ram_read_pointer_a when r_current_state = WRITE_RESULTS else
                               std_logic_vector(to_unsigned(r_current_lr_y_offset + r_current_lr_x, w_disparity_ram_address_a'length));

  w_disparity_ram_address_b <= std_logic_vector(unsigned(r_disparity_ram_write_pointer_b) + c_disparity_image_2_offset) when r_current_state = LOAD_DISPARITY else
                               std_logic_vector(unsigned(r_disparity_ram_read_pointer_b) + c_disparity_image_2_offset) when r_current_state = WRITE_RESULTS else
                               std_logic_vector(to_unsigned(r_current_lr_y_offset + r_current_lr_x + to_integer(unsigned("00" & w_disparity_ram_q_a)), w_disparity_ram_address_b'length));

end architecture TESTBENCH;
