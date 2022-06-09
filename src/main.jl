include("utils.jl")

# OPTIMIZATION SOLVE PARAMETERS
# increase stop values or decrease time limit for faster and less precise solution
global maxtime = 600
global relstop = 1e-3
global gapstop = 1e-4
global primalstop = 1e-4

# BATTERY SPECIFICATIONS
# in order to achieve reasonable solve time, battery sizing is fixed
num_batteries_in_BESS = 2 # batteries in series
volts_per_battery = 12.8
amp_hours_per_battery = 54
max_amps_per_battery = 25
BESS_total_cost = 948
global BESS_size_kwh = BESS_kwh(num_batteries=num_batteries_in_BESS, volts=volts_per_battery, amp_hours=amp_hours_per_battery)
global BESS_size_kw = BESS_kw(num_batteries=num_batteries_in_BESS, volts=volts_per_battery, max_amps=max_amps_per_battery)
global BESS_capx_cost_per_kwh = BESS_total_cost / size_kwh

# PV SPECIFICATIONS
global PV_capx_cost_per_kw = 4800
global PV_om_cost_per_kw_per_year = 48

# SCENARIOS
global sites = [
        # Dict("name" => "fairbanks","longitude" => -149.8514, "latitude" => 61.1975),
        # Dict("name" => "huslia","longitude" => -156.383, "latitude" => 65.7),
        Dict("name" => "aniak", "longitude" => -159.533, "latitude" => 61.583)
    ]
global warming_plus_deg_C = [
        0,
        2,
        5
    ] # each of these values indicates an analysis scenario where TMY temperature profile is increased by that amount


# RUN ANALYSIS

# run REopt and produce result JSON files for all of the scenarios defined above
# comment out in order to only summarize existing results JSON files
run_reopt_scenarios()

# summarize key results for all the scenarios defined above into a CSV file
# comment out in order to only run the REopt analysis and not generate a summary table
summarize_results()
