include("utils.jl")

# OPTIMIZATION SOLVE PARAMETERS
solver = "HiGHS" # options: "HiGHS" or "Xpress"
# increase MIP_relative_gap_stop or decrease max_solve_time for faster and less precise solution
max_solve_time = 1800.0
optimality_gap_relative_tolerance = 1e-2
primal_feasibility_tolerance = 1e-3
dual_feasibility_tolerance = 1e-3

# BATTERY SPECIFICATIONS
# in order to achieve reasonable solve time, battery sizing is fixed
num_batteries_in_BESS = 2 # batteries in series
volts_per_battery = 12.8
amp_hours_per_battery = 54
max_amps_per_battery = 25
BESS_total_cost = 948
BESS_size_kwh = BESS_kwh(num_batteries=num_batteries_in_BESS, volts=volts_per_battery, amp_hours=amp_hours_per_battery)
BESS_size_kw = BESS_kw(num_batteries=num_batteries_in_BESS, volts=volts_per_battery, max_amps=max_amps_per_battery)
BESS_capx_cost_per_kwh = BESS_total_cost / BESS_size_kwh

# PV SPECIFICATIONS
PV_capx_cost_per_kw = 4800
PV_om_cost_per_kw_per_year = 48

# SCENARIOS
sites = [
        # Dict("name" => "fairbanks","longitude" => -149.8514, "latitude" => 61.1975),
        # Dict("name" => "huslia","longitude" => -156.383, "latitude" => 65.7),
        Dict("name" => "aniak", "longitude" => -159.533, "latitude" => 61.583)
    ]
warming_plus_deg_C = [
        0,
        2,
        5
    ] # each of these values indicates an analysis scenario where TMY temperature profile is increased by that amount


# RUN ANALYSIS

RUN_REOPT = true
SUMMARIZE_RESULTS = true

# run REopt and produce result JSON files for all of the scenarios defined above
# comment out in order to only summarize existing results JSON files
if RUN_REOPT
    run_reopt_scenarios(solver=solver, 
                        sites=sites, warming_plus_deg_C=warming_plus_deg_C, 
                        BESS_size_kwh=BESS_size_kwh, BESS_size_kw=BESS_size_kw, 
                        BESS_capx_cost_per_kwh=BESS_capx_cost_per_kwh, 
                        PV_capx_cost_per_kw=PV_capx_cost_per_kw, 
                        PV_om_cost_per_kw_per_year=PV_om_cost_per_kw_per_year,
                        max_solve_time=max_solve_time,
                        optimality_gap_relative_tolerance=optimality_gap_relative_tolerance,
                        primal_feasibility_tolerance=primal_feasibility_tolerance,
                        dual_feasibility_tolerance=dual_feasibility_tolerance)
end

# summarize key results for all the scenarios defined above into a CSV file
# comment out in order to only run the REopt analysis and not generate a summary table
if SUMMARIZE_RESULTS
    summarize_results(sites=sites, warming_plus_deg_C=warming_plus_deg_C)
end