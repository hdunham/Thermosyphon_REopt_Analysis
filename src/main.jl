include("utils.jl")

# OPTIMIZATION SOLVE PARAMETERS
# increase stop values or decrease time limit for faster and less precise solution
global maxtime = 600
global relstop = 1e-3
global gapstop = 1e-4
global primalstop = 1e-4

# BATTERY SPECIFICATIONS
# in order to achieve reasonable solve time, battery sizing is fixed
num_batteries = 2
volts = 12.8
amp_hours = 54
max_amps = 25
global size_kwh = num_batteries * volts * amp_hours / 1000
global size_kw = num_batteries * volts * max_amps / 1000
total_cost = 948
global cost_kwh = total_cost / size_kwh

# SCENARIOS
global sites = [
        # Dict("name" => "fairbanks","longitude" => -149.8514, "latitude" => 61.1975),
        # Dict("name" => "huslia","longitude" => -156.383, "latitude" => 65.7),
        Dict("name" => "aniak", "longitude" => -159.533, "latitude" => 61.583)
    ]
# each of these values indicates an analysis scenario where TMY temperature profile is increased by that amount
global plus_deg_C_variations = [
        0,
        2,
        5
    ]


# RUN ANALYSIS

# run REopt and produce result JSON files for all of the scenarios defined above
# comment out in order to only summarize existing results JSON files
#run_reopt_scenarios()

# summarize key results for all the scenarios defined above into a CSV file
# comment out in order to only run the REopt analysis and not generate a summary table
summarize_results()
