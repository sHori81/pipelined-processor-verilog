# 1. Board input clock: 20 MHz
create_clock -name clk -period 50.000 [get_ports {clk}]

# 2. Display clock: 20 MHz
create_clock -name sel_clk -period 50.000 [get_ports {sel_clk}]

# 3. PLL-generated clocks
derive_pll_clocks

# 4. Clock uncertainty
derive_clock_uncertainty

# 5. Cut asynchronous paths between display clock and CPU/PLL clocks
set other_clocks [remove_from_collection [all_clocks] [get_clocks {sel_clk}]]

set_clock_groups -asynchronous \
    -group [get_clocks {sel_clk}] \
    -group $other_clocks


set_false_path -from [get_ports *]
set_false_path -to [get_ports *]
