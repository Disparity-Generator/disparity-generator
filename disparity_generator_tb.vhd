library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;
  use ieee.std_logic_textio.all;

entity DIPARITY_GENERATOR_TB is -- keine Schnittstellen
end entity DIPARITY_GENERATOR_TB;

architecture TESTBENCH of DIPARITY_GENERATOR_TB is

  component DISPARITY_GENERATOR is
    generic (
      G_IMAGE_WIDTH       : integer := 640;
      G_IMAGE_HEIGHT      : integer := 480;
      G_BLOCK_SIZE        : integer := 10;
      G_MINIMAL_DISPARITY : integer := 120;
      G_MAXIMUM_DISPARITY : integer := 150;
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

  procedure discard_separator (
    variable line_pointer : inout line
  ) is

    variable dump : string(1 to 1);

  begin

    read(line_pointer, dump);

  end procedure;

  procedure get_integer (
    variable line_pointer : inout line;
    variable int_out        : out integer) is

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
  signal clk_tb_s                           : std_logic;
  signal w_reset_n                          : std_logic;
  signal w_write_enable                     : std_logic;
  signal w_pixel                            : std_logic_vector(7 downto 0);
  signal w_ready                            : std_logic;
  signal w_disparity_pixel                  : std_logic_vector(7 downto 0);
  signal w_disparity_pixel_valid            : std_logic;

  signal r_write_enable                     : std_logic := '0';
  signal r_write_enable_delay               : std_logic := '0';
  signal r_pixel                            : std_logic_vector(9 downto 0);
  signal w_disparity_in                            : std_logic_vector(9 downto 0);


  signal r_disparity_row_count              : integer := 0;

  constant c_block_size                     : integer := 5;
  constant c_image_width                    : integer := 640;
  constant c_image_height                   : integer := 480;
  constant c_background_threshold : integer := 256;

  constant c_disparity_width                : integer := c_image_width / c_block_size;
  constant c_disparity_height               : integer := c_image_height / c_block_size;

  constant c_result_image_width             : integer := c_image_width / c_block_size;
  constant c_result_image_height            : integer := c_image_height / c_block_size;

  constant c_minimal_disparity              : integer := 0;
  constant c_maximum_disparity              : integer := 999;

  type out_memory is ARRAY (0 to c_result_image_height - 1, 0 to c_result_image_width - 1) of integer;

  signal result_image                       : out_memory;

  -- constant c_filename_image1                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild1_inc.csv";
  -- constant c_filename_image1                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild1_inc_klein.csv";
  constant c_filename_image1                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\bild1_sw.csv";
  -- constant c_filename_image2                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild1_inc.csv";
  -- constant c_filename_image2                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\bild2_inc_klein.csv";
  constant c_filename_image2                : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\bild2_sw.csv";
  constant c_filename_out                   : string := "C:\Users\Schul\Entwicklung\QuartusProjekte\Abschlussprojekt\disparity_generator\disparity_lr.csv";

  file   fptr                               : text;
  signal test_int                           : integer;
  -- signal test_string : string(1 to 1);

  signal r_line_opened                      : std_logic := '0';

  signal test_string                        : string(1 to 1);

  type t_states is (CLOSE_FILE, WAIT_FOR_READY, TRANSMIT_IMAGE1, TRANSMIT_IMAGE2, LOAD_DISPARITY, FINISHED);

  signal w_next_state                       : t_states;
  signal r_current_state                    : t_states := CLOSE_FILE;

  -- Current column and of the first image to load
  -- Row 0 <= x < block_size
  -- Values get reset after each load
  signal r_image1_load_col                  : integer := 0;
  signal r_image1_load_row                  : integer := 0;

  signal r_image2_load_col                  : integer := 0;
  signal r_image2_load_row                  : integer := 0;


  -- Current row in the images
  signal r_image1_row_pointer               : integer := 0;
  signal r_image2_row_pointer               : integer := 0;

  -- Current column and row of the result image
  signal r_disparity_column                 : integer := 0;
  signal r_disparity_row                    : integer := 0;

  signal r_mean_value_left : integer range 0 to 999999999;
  signal r_mean_value_right : integer range 0 to 999999999;

  constant c_mean_left : integer := 143;
  constant c_mean_right : integer := 172;

begin

  DUT : DISPARITY_GENERATOR
    generic map (
      G_IMAGE_WIDTH       => c_image_width,
      G_IMAGE_HEIGHT      => c_image_height,
      G_BLOCK_SIZE        => c_block_size,
      G_MINIMAL_DISPARITY => c_minimal_disparity,
      G_MAXIMUM_DISPARITY => c_maximum_disparity,
      G_BACKGROUND_THRESHOLD => c_background_threshold
    )
    port map (
      I_CLOCK                 => clk_tb_s,
      I_RESET_N               => w_reset_n,
      I_WRITE_ENABLE          => r_write_enable,
      I_PIXEL                 => w_disparity_in,
      O_READY                 => w_ready,
      O_DISPARITY_PIXEL       => w_disparity_pixel,
      O_DISPARITY_PIXEL_VALID => w_disparity_pixel_valid
    );

  P_CLK : process is

  begin

    clk_tb_s <= '1';
    wait for 5 ns;
    clk_tb_s <= '0';
    wait for 5 ns;

  end process P_CLK;

  PROC_STATE_OUT : process (w_disparity_pixel_valid, r_current_state, r_image1_load_col, r_image1_load_row, r_image2_load_col, r_image2_load_row, r_disparity_column, r_disparity_row, w_ready) is

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

        if (w_ready = '1') then
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

        if (r_disparity_column = c_image_width / c_block_size - 1 and r_disparity_row < c_image_height / c_block_size - 1 and w_disparity_pixel_valid = '1') then
          w_next_state <= TRANSMIT_IMAGE1;
        elsif (r_disparity_column = c_image_width / c_block_size - 1 and r_disparity_row = c_image_height / c_block_size - 1 and w_disparity_pixel_valid = '1') then
          w_next_state <= FINISHED;
        else
          w_next_state <= LOAD_DISPARITY;
        end if;

        w_write_enable <= '0';


      when FINISHED =>
        w_write_enable <= '0';

    end case;

  end process PROC_STATE_OUT;

  PROC_STATE_FF : process (w_reset_n, clk_tb_s) is
  begin

  end process PROC_STATE_FF;

  PROC_FILE_HANDLER_IN : process (w_reset_n, clk_tb_s) is

    variable fstatus  : file_open_status;
    variable line_out : line;

    file image1 : text open read_mode is c_filename_image1;
    file image2 : text open read_mode is c_filename_image2;

    variable current_image1_line : line;
    variable current_image2_line : line;

    variable pixel_left : std_logic_vector(7 downto 0);
    variable pixel_right : std_logic_vector(7 downto 0);

  begin

    if (w_reset_n = '0') then
      r_pixel         <= (others => '0');
      r_current_state <= WAIT_FOR_READY;
    elsif (rising_edge(clk_tb_s)) then
      r_current_state <= w_next_state;

      case r_current_state is

        when CLOSE_FILE =>
          file_close(fptr);

        when WAIT_FOR_READY =>
          file_open(fstatus, fptr, c_filename_out, write_mode);
          readline(image1, current_image1_line);
          readline(image2, current_image2_line);

          when TRANSMIT_IMAGE1 =>
          if (r_write_enable = '1') then
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
          if (r_write_enable = '1') then
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
          if (w_disparity_pixel_valid = '1') then
            result_image(r_disparity_row, r_disparity_column) <= to_integer(unsigned(w_disparity_pixel));

            write(line_out, to_integer(unsigned(w_disparity_pixel)));

            if (r_disparity_column < c_image_width / c_block_size - 1) then
              write(line_out, string'(","));
            else
              writeline(fptr, line_out);
            end if;

            if (r_disparity_column < c_result_image_width - 1) then
              r_disparity_column <= r_disparity_column + 1;
            else
              r_disparity_column <= 0;
            end if;

            if (r_disparity_column = c_result_image_width - 1) then
              r_disparity_row <= r_disparity_row + 1;
            end if;
          end if;

          r_image1_load_col <= 0;
          r_image1_load_row <= 0;
          r_image2_load_col <= 0;
          r_image2_load_row <= 0;


        when FINISHED =>
          file_close(fptr);

      end case;

    end if;

  end process PROC_FILE_HANDLER_IN;


  PROC_WRITE_ENABLE_DELAY : process (w_reset_n, clk_tb_s) is
  begin

    if (w_reset_n = '0') then
      r_write_enable <= '0';
    elsif (rising_edge(clk_tb_s)) then
      r_write_enable_delay <= w_write_enable;
      r_write_enable       <= r_write_enable_delay;
    end if;

  end process PROC_WRITE_ENABLE_DELAY;

  w_reset_n <= '1';

  w_disparity_in <= std_logic_vector(to_signed(to_integer(signed(r_pixel)) - c_mean_left, 10)) when r_current_state = TRANSMIT_IMAGE1 else std_logic_vector(to_signed(to_integer(signed(r_pixel)) - c_mean_right, 10));

end architecture TESTBENCH;
