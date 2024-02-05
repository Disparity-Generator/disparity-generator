library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

--! This module calculates the reverse (right to left) disparity from two images.
--! When both directions are calculated, these disparity images can be compared.
--! By comparing the differences, errors can be filtered out and possibly interpolated.
--! It compares one block row at once. To calculate a whole image, this process has to be repeated multiple times.
--! The component works like the left to right version but we start right, thus count backwards.

entity DISPARITY_GENERATOR_REVERSE is
  generic (
    G_IMAGE_WIDTH          : integer := 640;  -- The width of the **original** image
    G_IMAGE_HEIGHT         : integer := 480;  -- The height of the **original** image
    G_BLOCK_SIZE           : integer := 8;    -- Size of the block to compare both images
    G_MINIMAL_DISPARITY    : integer := 0;    -- If calculated disparity is lower than that value, the value is discarded
    G_MAXIMUM_DISPARITY    : integer := 9999; -- If calculated disparity is higher than that value, the value is discarded
    G_BACKGROUND_THRESHOLD : integer := 256;  -- If the mean value of the left block is higher than that value, the pixel is discarded.
    G_MAX_SAD              : integer := 1000  -- Not used
  );
  port (
    I_CLOCK                 : in    std_logic;
    I_RESET_N               : in    std_logic;
    I_WRITE_ENABLE          : in    std_logic;
    I_PIXEL                 : in    std_logic_vector(9 downto 0); --! SIGNED input pixel

    O_READY                 : out   std_logic;                    --! High when the current processing is done.
    O_DISPARITY_PIXEL       : out   std_logic_vector(7 downto 0);
    O_DISPARITY_PIXEL_VALID : out   std_logic
  );
end entity DISPARITY_GENERATOR_REVERSE;

architecture ARCH of DISPARITY_GENERATOR_REVERSE is

  type t_states is (
    IDLE,
    STORE_LEFT,
    STORE_RIGHT,
    PRELOAD_FIRST_RIGHT_PIXEL,
    LOAD_LEFT_BLOCK,
    LOAD_RIGHT_BLOCK,
    COMPARE_BLOCKS
  );

  signal w_next_state                                                     : t_states;
  signal r_current_state                                                  : t_states := IDLE;

  --! The number of words to read is as big as the row width * block size
  constant c_row_write_amount                                             : integer := G_IMAGE_WIDTH * G_BLOCK_SIZE - 1;

  --! The amount of blocks to process on the left
  constant c_right_block_amount                                           : integer := integer(floor(real(G_IMAGE_WIDTH) / real(G_BLOCK_SIZE)));

  --! The amount of blocks to process on the right
  constant c_left_block_amount                                            : integer := G_IMAGE_WIDTH - G_BLOCK_SIZE + 1;

  constant c_pixel_amount                                                 : integer := G_IMAGE_WIDTH * G_BLOCK_SIZE;

  --! Value to use as reset value for sum of all differences. It has to be very high because we are searching for low values.
  constant c_base_sad                                                     : integer := 2 * 255 * G_BLOCK_SIZE * G_BLOCK_SIZE + 1;

  -- To prevent the need of divisions, the calculation is done backwards.
  -- Instead of dividing some sum by the amount of pixels to get the mean, we simply use the whole sum as threshold.
  -- For a better usability, the user can enter the threshold without multiplying. It's done here.
  -- Every field with a mean intensity above the threshold will be detected as background and discarded as 0 disparity.
  constant c_background_threshold                                         : integer := G_BACKGROUND_THRESHOLD * G_BLOCK_SIZE * G_BLOCK_SIZE;

  type t_pixel_block is array (0 to G_BLOCK_SIZE - 1, 0 to G_BLOCK_SIZE - 1) of integer range -999 to 999;

  signal r_current_left_block                                             : t_pixel_block;
  signal r_current_right_block                                            : t_pixel_block;
  signal r_sum_block                                                      : t_pixel_block;

  signal r_background_detected                                            : std_logic := '0';

  signal r_read_pointer_left                                              : std_logic_vector(12 downto 0) := (others => '0');
  signal r_read_pointer_right                                             : std_logic_vector(12 downto 0) := (others => '0');

  signal w_read_pointer_left                                              : std_logic_vector(12 downto 0);
  signal w_read_pointer_right                                             : std_logic_vector(12 downto 0);

  signal r_write_pointer_left                                             : std_logic_vector(12 downto 0) := (others => '0');
  signal r_write_pointer_right                                            : std_logic_vector(12 downto 0) := (others => '0');

  signal w_write_pointer_left                                             : std_logic_vector(12 downto 0);
  signal w_write_pointer_right                                            : std_logic_vector(12 downto 0);

  signal w_cache_left_q                                                   : std_logic_vector(9 downto 0);
  signal w_cache_right_q                                                  : std_logic_vector(9 downto 0);

  signal r_cache_right_q                                                  : std_logic_vector(9 downto 0);

  signal w_we_cache_left                                                  : std_logic;
  signal w_we_cache_right                                                 : std_logic;

  signal r_we_cache                                                       : std_logic := '0';

  signal r_pixel                                                          : std_logic_vector(9 downto 0) := (others => '0');
  signal w_cache_left_in                                                  : std_logic_vector(9 downto 0) := (others => '0');
  signal w_cache_right_in                                                 : std_logic_vector(9 downto 0) := (others => '0');

  signal r_disparity_valid                                                : std_logic := '0';

  signal w_ready                                                          : std_logic;

  signal r_current_write_col_right                                        : integer range 0 to G_IMAGE_WIDTH;
  signal r_current_write_row_right                                        : integer range 0 to G_BLOCK_SIZE;
  signal r_current_write_row_left                                         : integer range 0 to G_BLOCK_SIZE;

  -- The amount of blocks depends on the size of the row and the amount of blocks.
  -- On the left side we are moving to the right in steps of a whole block.
  -- On the right we are moving pixelwise, thus the ranges of the according current block integers differ.
  signal r_current_block_left                                             : integer range -1 to 9999999 := 0;

  signal r_current_matrix_write_column_left                               : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_write_row_left                                  : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_read_column_left                                : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_read_row_left                                   : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_matrix_counter_enable                                          : std_logic                           := '1';

  signal r_current_matrix_write_column_right                              : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_write_row_right                                 : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_read_column_right                               : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_read_row_right                                  : integer range 0 to G_BLOCK_SIZE - 1 := 0;

  signal r_current_sum_left                                               : integer range -999 * G_BLOCK_SIZE * G_BLOCK_SIZE to 999 * G_BLOCK_SIZE * G_BLOCK_SIZE := 0;

  signal r_current_block_right                                            : integer range -1 to c_right_block_amount := 0;

  signal r_current_sum_right                                              : integer range -999 * G_BLOCK_SIZE * G_BLOCK_SIZE to 999 * G_BLOCK_SIZE * G_BLOCK_SIZE := 0;

  signal r_current_matrix_column                                          : integer range 0 to G_BLOCK_SIZE - 1 := 0;
  signal r_current_matrix_row                                             : integer range 0 to G_BLOCK_SIZE - 1 := 0;

  signal r_current_disparity                                              : integer range 0 to 999999999 := 0;
  signal r_current_sad                                                    : integer range 0 to 999999999 := 0;
  signal r_current_difference                                             : integer range -1000 to 10000;
  signal r_current_lowest_sad                                             : integer range 0 to 999999999 := c_base_sad;

  signal w_current_sum_of_absolute_differences                            : integer range 0 to 99999999;

  signal r_write_enable                                                   : std_logic;
  signal r_in_pixel                                                       : std_logic_vector(9 downto 0);

  signal w_oc_ram_address_left                                            : std_logic_vector(12 downto 0);
  signal w_oc_ram_address_right                                           : std_logic_vector(12 downto 0);

  component OC_RAM is
    port (
      CLOCK        : in    std_logic  := '1';
      DATA         : in    std_logic_vector(9 downto 0);
      ADDRESS      : in    std_logic_vector(12 downto 0);
      WREN         : in    std_logic  := '0';
      Q            : out   std_logic_vector(9 downto 0)
    );
  end component oc_ram;

begin

  -- To calculate the pixel disparities, both sides need to be cached.
  -- Since the values are needed multiple times the rows are cached to reduce SDRAM accesses.
  ROW_CACHE_LEFT_IMAGE : OC_RAM
    port map (
      CLOCK   => I_CLOCK,
      DATA    => w_cache_left_in,
      ADDRESS => w_oc_ram_address_left,
      WREN    => w_we_cache_left,
      Q       => w_cache_left_q
    );

  ROW_CACHE_RIGHT_IMAGE : OC_RAM
    port map (
      CLOCK   => I_CLOCK,
      DATA    => w_cache_right_in,
      ADDRESS => w_oc_ram_address_right,
      WREN    => w_we_cache_right,
      Q       => w_cache_right_q
    );

  w_cache_left_in  <= r_in_pixel;
  w_cache_right_in <= r_in_pixel;

  -- The cache ram addresses are integers, but the image is processed in x and y coordinates. 
  -- To ease the process, the processing is done with coordinates and these coordinates are mapped to ram addresses.
  w_read_pointer_right <= std_logic_vector(to_unsigned(r_current_matrix_read_column_right + (r_current_block_right * G_BLOCK_SIZE) + (r_current_matrix_read_row_right * G_IMAGE_WIDTH), w_read_pointer_right'length));
  w_read_pointer_left  <= std_logic_vector(to_unsigned(r_current_matrix_read_column_left + r_current_block_left + (r_current_matrix_read_row_left * G_IMAGE_WIDTH), w_read_pointer_left'length));

  w_oc_ram_address_right <= w_read_pointer_right when w_we_cache_right = '0' else
                            r_write_pointer_right;
  w_oc_ram_address_left  <= w_read_pointer_left when w_we_cache_left = '0' else
                            r_write_pointer_left;

  PROC_STATE_MACHINE_OUT : process (r_write_enable, r_background_detected, r_current_block_left, r_current_matrix_write_column_right, r_current_matrix_write_row_right, r_current_matrix_write_row_left, r_current_matrix_write_column_left, r_write_pointer_right, r_current_block_right, r_current_state, I_WRITE_ENABLE, r_write_pointer_left, r_current_write_col_right, r_current_write_row_right, r_read_pointer_left, r_read_pointer_right, w_we_cache_right, w_we_cache_left) is

  begin

    case r_current_state is

      when IDLE =>

        if (I_WRITE_ENABLE = '1') then
          w_next_state <= STORE_LEFT;
        else
          w_next_state <= IDLE;
        end if;

        w_we_cache_left  <= '0';
        w_we_cache_right <= '0';
        w_ready          <= '1';

      -- At first, the left and right rows are cached.
      when STORE_LEFT =>

        if (to_integer(unsigned(r_write_pointer_left)) = c_pixel_amount - 1) then
          w_next_state <= STORE_RIGHT;
        else
          w_next_state <= STORE_LEFT;
        end if;

        w_we_cache_left  <= r_write_enable;
        w_we_cache_right <= '0';
        w_ready          <= '0';

      when STORE_RIGHT =>

        if (to_integer(unsigned(r_write_pointer_right)) = c_pixel_amount - 1) then
          w_next_state <= PRELOAD_FIRST_RIGHT_PIXEL;
        else
          w_next_state <= STORE_RIGHT;
        end if;

        w_we_cache_left  <= '0';
        w_we_cache_right <= r_write_enable;
        w_ready          <= '0';

      when PRELOAD_FIRST_RIGHT_PIXEL =>

        w_next_state <= LOAD_RIGHT_BLOCK;

        w_we_cache_left  <= '0';
        w_we_cache_right <= '0';
        w_ready          <= '0';

      when LOAD_RIGHT_BLOCK =>

        if (r_current_matrix_write_column_right = G_BLOCK_SIZE - 1 and r_current_matrix_write_row_right = G_BLOCK_SIZE - 1) then
          if (r_background_detected = '1') then
            w_next_state <= COMPARE_BLOCKS;
          else
            w_next_state <= LOAD_LEFT_BLOCK;
          end if;
        else
          w_next_state <= LOAD_RIGHT_BLOCK;
        end if;

        w_we_cache_left  <= '0';
        w_we_cache_right <= '0';
        w_ready          <= '0';

      when LOAD_LEFT_BLOCK =>

        if (r_background_detected = '1') then
          w_next_state <= COMPARE_BLOCKS;
        elsif (r_current_matrix_write_column_left = G_BLOCK_SIZE - 1 and r_current_matrix_write_row_left = G_BLOCK_SIZE - 1) then
          w_next_state <= COMPARE_BLOCKS;
        else
          w_next_state <= LOAD_LEFT_BLOCK;
        end if;

        w_we_cache_left  <= '0';
        w_we_cache_right <= '0';
        w_ready          <= '0';

      when COMPARE_BLOCKS =>

        if (r_background_detected = '1') then
          if (r_current_block_right = 0) then
            w_next_state <= LOAD_RIGHT_BLOCK;
          else
            w_next_state <= IDLE;
          end if;
        elsif (r_current_block_right > -1) then
          if (r_current_block_left = -1 or r_current_block_left - r_current_block_right * G_BLOCK_SIZE > G_MAXIMUM_DISPARITY) then
            w_next_state <= LOAD_RIGHT_BLOCK;
          else
            w_next_state <= LOAD_LEFT_BLOCK;
          end if;
        else
          w_next_state <= IDLE;
        end if;

        w_we_cache_left  <= '0';
        w_we_cache_right <= '0';
        w_ready          <= '0';

    end case;

  end process PROC_STATE_MACHINE_OUT;

  PROC_STATE_FF : process (I_RESET_N, I_CLOCK) is

  begin

    if (I_RESET_N = '0') then
      r_current_state          <= IDLE;
      r_background_detected    <= '0';
      r_in_pixel               <= (others => '0');
      r_current_write_row_left <= 0;

      r_current_write_row_left <= 0;
      r_write_pointer_left     <= (others => '0');
      r_write_pointer_right    <= (others => '0');
      r_read_pointer_right     <= (others => '0');
      r_read_pointer_left      <= (others => '0');

      r_current_matrix_read_column_left  <= 0;
      r_current_matrix_read_column_right <= 0;
      r_current_matrix_read_row_left     <= 0;
      r_matrix_counter_enable            <= '1';

      r_current_matrix_read_row_right <= 0;

      r_current_matrix_write_column_left  <= 0;
      r_current_matrix_write_column_right <= 0;

      r_current_matrix_write_row_left  <= 0;
      r_current_matrix_write_row_right <= 0;

      r_current_disparity   <= 0;
      r_current_lowest_sad  <= c_base_sad;
      r_disparity_valid     <= '0';
      r_current_block_left  <= 0;
      r_current_block_right <= 0;

      r_current_left_block  <= (others => (others => 1));
      r_current_right_block <= (others => (others => 1));

      r_current_sum_left <= 0;

      r_current_block_right <= 0;

      r_current_difference <= 0;
      r_current_sad        <= 0;
    elsif (rising_edge(I_CLOCK)) then
      r_current_state <= w_next_state;

      r_in_pixel     <= I_PIXEL;
      r_write_enable <= I_WRITE_ENABLE;

      case r_current_state is

        when IDLE =>
          r_current_write_row_left <= 0;
          r_write_pointer_left     <= (others => '0');
          r_write_pointer_right    <= (others => '0');

          r_current_matrix_read_column_left  <= 0;
          r_current_matrix_read_column_right <= 0;

          r_current_matrix_write_column_left  <= 0;
          r_current_matrix_write_column_right <= 0;

          r_current_disparity  <= 0;
          r_current_lowest_sad <= c_base_sad;
          r_disparity_valid    <= '0';

        when STORE_LEFT =>

          if (I_WRITE_ENABLE = '1') then
            if (to_integer(unsigned(r_write_pointer_left)) < c_pixel_amount - 1) then
              r_write_pointer_left <= std_logic_vector(unsigned(r_write_pointer_left) + to_unsigned(1, r_write_pointer_left'length));
            else
              r_write_pointer_left <= (others => '0');
            end if;
          end if;

          if (to_integer(unsigned(r_read_pointer_left)) < c_pixel_amount - 1) then
            r_read_pointer_left <= std_logic_vector(unsigned(r_read_pointer_left) + to_unsigned(1, r_read_pointer_left'length));
          else
            r_read_pointer_left <= (others => '0');
          end if;

          r_disparity_valid     <= '0';
          r_current_block_left  <= c_left_block_amount - G_BLOCK_SIZE - 1;
          r_current_block_right <= c_right_block_amount - 1;

        when STORE_RIGHT =>

          if (r_write_enable = '1') then
            if (to_integer(unsigned(r_write_pointer_right)) < c_pixel_amount - 1) then
              r_write_pointer_right <= std_logic_vector(unsigned(r_write_pointer_right) + to_unsigned(1, r_write_pointer_right'length));
            else
              r_write_pointer_right <= (others => '0');
            end if;
          end if;

          r_disparity_valid <= '0';

        when PRELOAD_FIRST_RIGHT_PIXEL =>

          r_current_matrix_read_column_right <= 1;

        when LOAD_RIGHT_BLOCK =>
          r_disparity_valid   <= '0';
          r_current_disparity <= 0;

          r_current_right_block(r_current_matrix_write_row_right, r_current_matrix_write_column_right) <= to_integer(signed(w_cache_right_q));
          r_current_sum_right                                                                          <= r_current_sum_left + to_integer(signed(w_cache_right_q));

          r_current_block_left <= r_current_block_right * G_BLOCK_SIZE;

          if (r_current_matrix_read_column_right < G_BLOCK_SIZE - 1) then
            r_current_matrix_read_column_right <= r_current_matrix_read_column_right + 1;
          else
            r_current_matrix_read_column_right <= 0;
          end if;

          if (r_current_matrix_read_column_right = G_BLOCK_SIZE - 1) then
            if (r_current_matrix_read_row_right < G_BLOCK_SIZE - 1) then
              r_current_matrix_read_row_right <= r_current_matrix_read_row_right + 1;
            else
              r_current_matrix_read_row_right <= 0;
            end if;
          end if;

          if (r_current_matrix_write_column_right < G_BLOCK_SIZE - 1) then
            r_current_matrix_write_column_right <= r_current_matrix_write_column_right + 1;
          else
            r_current_matrix_write_column_right <= 0;
          end if;

          if (r_current_matrix_write_column_right = G_BLOCK_SIZE - 1) then
            if (r_current_matrix_write_row_right < G_BLOCK_SIZE - 1) then
              r_current_matrix_write_row_right <= r_current_matrix_write_row_right + 1;
            else
              r_current_matrix_write_row_right <= 0;
            end if;
          end if;

          r_current_matrix_read_column_left <= 0;

          if ((r_current_matrix_write_row_right >= G_BLOCK_SIZE - 1 and r_current_matrix_write_column_right = G_BLOCK_SIZE - 1) or r_background_detected = '1') then
            -- The address is registered, thus one word needs to be preloaded.
            r_current_matrix_read_column_left <= 1;
            if (r_current_block_right > -1) then
              r_current_block_right <= r_current_block_right - 1;
            else
              r_current_block_right <= c_right_block_amount - G_BLOCK_SIZE - 1;
            end if;
          end if;

        when LOAD_LEFT_BLOCK =>

          if (r_matrix_counter_enable = '1') then
            if (r_current_matrix_read_column_left < G_BLOCK_SIZE - 1) then
              r_current_matrix_read_column_left <= r_current_matrix_read_column_left + 1;
            else
              r_current_matrix_read_column_left <= 0;
            end if;

            if (r_current_matrix_read_column_left = G_BLOCK_SIZE - 1 and r_current_matrix_read_row_left < G_BLOCK_SIZE - 1) then
              r_current_matrix_read_row_left <= r_current_matrix_read_row_left + 1;
            end if;

            if (r_current_matrix_read_column_left = G_BLOCK_SIZE - 1 and r_current_matrix_read_row_left = G_BLOCK_SIZE - 1) then
              r_current_matrix_read_row_left <= 0;
              r_matrix_counter_enable        <= '0';

              if (r_current_block_left > -1) then
                r_current_block_left <= r_current_block_left - 1;
              else
                r_current_block_left <= c_left_block_amount - G_BLOCK_SIZE - 1;
              end if;
            end if;
          end if;

          if (r_current_matrix_write_column_left < G_BLOCK_SIZE - 1) then
            r_current_matrix_write_column_left <= r_current_matrix_write_column_left + 1;
          else
            r_current_matrix_write_column_left <= 0;
          end if;

          if (r_current_matrix_write_column_left = G_BLOCK_SIZE - 1) then
            if (r_current_matrix_write_row_left < G_BLOCK_SIZE - 1) then
              r_current_matrix_write_row_left <= r_current_matrix_write_row_left + 1;
            else
              r_current_matrix_write_row_left <= 0;
            end if;
          end if;

          if (r_matrix_counter_enable = '0') then
            r_matrix_counter_enable <= '1';
          end if;

          r_current_matrix_read_column_right <= 0;

          r_disparity_valid                                                                         <= '0';
          r_current_left_block(r_current_matrix_write_row_left, r_current_matrix_write_column_left) <= to_integer(signed(w_cache_left_q));
          r_current_difference                                                                      <= r_current_right_block(r_current_matrix_write_row_left, r_current_matrix_write_column_left) - to_integer(signed(w_cache_left_q));
          r_current_sad                                                                             <= r_current_sad + abs(r_current_difference);

        -- The last step is to compare both blocks. 
        -- The pair of blocks with the lowest sum is chosen. 
        -- The distance between those blocks is the disparity value of the current pixel. 
        when COMPARE_BLOCKS =>

          if (r_current_sad + abs(r_current_difference) < r_current_lowest_sad) then
            r_current_lowest_sad <= r_current_sad;
            r_current_disparity  <= abs((r_current_block_right - 1) * G_BLOCK_SIZE - (r_current_block_left - 1));
          end if;
          -- The address is registered, thus one word needs to be preloaded.
          r_current_matrix_read_column_right <= 1;

          if (w_next_state = LOAD_RIGHT_BLOCK or w_next_state = IDLE) then
            r_disparity_valid    <= '1';
            r_current_lowest_sad <= c_base_sad;
          else
            r_disparity_valid <= '0';
          end if;

          -- If a background threshold value is chosen and the mean value of the left block
          -- is above that value, the current block is discarded. 
          -- This can be used to filter out white background like floors.
          if (r_background_detected = '1') then
            r_current_disparity   <= 0;
            r_current_lowest_sad  <= c_base_sad;
            r_disparity_valid     <= '1';
            r_background_detected <= '0';
          end if;

          r_current_matrix_read_column_left <= 1;

          r_matrix_counter_enable <= '1';
          r_current_sad           <= 0;
          r_current_sum_left      <= 0;

      end case;

    end if;

  end process PROC_STATE_FF;

  O_DISPARITY_PIXEL       <= (others => '0') when r_current_disparity <= G_MINIMAL_DISPARITY or r_current_disparity >= G_MAXIMUM_DISPARITY else
                             std_logic_vector(to_unsigned(r_current_disparity, O_DISPARITY_PIXEL'length));
  O_DISPARITY_PIXEL_VALID <= r_disparity_valid;
  O_READY                 <= w_ready;

end architecture ARCH;
