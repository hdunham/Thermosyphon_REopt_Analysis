using JuMP
using Xpress
using HiGHS
using REopt
using DataFrames
using Plots
import JSON
import CSV


function results_filename(; site_name::String, warming_plus_deg_C::Real)
    if warming_plus_deg_C == 0
        plus_deg_string = ""
    else
        plus_deg_string = "_plus$(warming_plus_deg_C)C"
    end
    return "results/thermosyphon_results_$(lowercase(site_name))$(plus_deg_string).json"
end

function run_reopt_scenarios(; solver_name::String, 
                            sites::Vector{Dict{String,Any}}, 
                            warming_plus_deg_C::Vector{<:Real}, 
                            BESS_size_kwh::Real, BESS_size_kw::Real, 
                            BESS_capx_cost_per_kwh::Real, 
                            PV_capx_cost_per_kw::Real, 
                            PV_om_cost_per_kw_per_year::Real,
                            max_solve_time::Real=3600.0,
                            optimality_gap_relative_tolerance::Real=1e-4,
                            primal_feasibility_tolerance::Real=1e-6,
                            dual_feasibility_tolerance::Real=1e-6)
    PV_prod_factor_col_name = "ProdFactor"
    temp_deg_C_col_name = "TempC"

    inputs = JSON.parsefile(joinpath("data","thermosyphon_scenario.json"))
    if !("loads_kw" in keys(inputs["ElectricLoad"]))
        inputs["ElectricLoad"]["loads_kw"] = zeros(8760)
    end
    inputs["PV"]["max_kw"] = BESS_size_kw*2 # tightened max can help reduce solve time
    inputs["PV"]["installed_cost_per_kw"] = PV_capx_cost_per_kw
    inputs["PV"]["om_cost_per_kw"] = PV_om_cost_per_kw_per_year
    inputs["ElectricStorage"]["min_kw"] = BESS_size_kw
    inputs["ElectricStorage"]["max_kw"] = BESS_size_kw
    inputs["ElectricStorage"]["min_kwh"] = BESS_size_kwh
    inputs["ElectricStorage"]["max_kwh"] = BESS_size_kwh
    inputs["ElectricStorage"]["installed_cost_per_kw"] = 0
    inputs["ElectricStorage"]["installed_cost_per_kwh"] = BESS_capx_cost_per_kwh
    inputs["ElectricStorage"]["replace_cost_per_kw"] = 0
    inputs["ElectricStorage"]["replace_cost_per_kwh"] = BESS_capx_cost_per_kwh
    inputs["ElectricStorage"]["inverter_replacement_year"] = 10
    inputs["ElectricStorage"]["battery_replacement_year"] = 10

    for site in sites
        # df_results_summary = DataFrame("Warming scenario" => ["Active cooling needed (MMBtu)", "PV size (W)", "Battery size (W)", "Battery size (Wh)"])
        site_name = site["name"]
        for plus_deg in warming_plus_deg_C
            inputs["Site"]["longitude"] = site["longitude"]
            inputs["Site"]["latitude"] = site["latitude"]
            weather_file = CSV.File(joinpath("data","$(lowercase(site_name))_weather.csv"))
            prod_factor =  getproperty(weather_file,Symbol(PV_prod_factor_col_name))
            amb_temp_degF =  (getproperty(weather_file,Symbol(temp_deg_C_col_name)) .+ plus_deg) .* 1.8 .+ 32
            inputs["PV"]["prod_factor_series"] = prod_factor
            inputs["Thermosyphon"]["ambient_temp_degF"] = amb_temp_degF

            if solver_name == "Xpress"
                m = Model(optimizer_with_attributes(
                    Xpress.Optimizer, 
                    "MAXTIME" => max_solve_time,
                    "MIPRELSTOP" => optimality_gap_relative_tolerance,
                    "BARPRIMALSTOP" => primal_feasibility_tolerance,
                    "BARDUALSTOP" => dual_feasibility_tolerance)
                )
            elseif solver_name == "HiGHS"
                m = Model(optimizer_with_attributes(
                    HiGHS.Optimizer, 
                    "time_limit" => max_solve_time,
                    "mip_rel_gap" => optimality_gap_relative_tolerance, 
                    "primal_feasibility_tolerance" => primal_feasibility_tolerance,
                    "dual_feasibility_tolerance" => dual_feasibility_tolerance,
                    "output_flag" => false, 
                    "log_to_console" => false)
                )
            else
                throw(@error "Solver $(solver_name) not supported. Either choose a supported solver (HiGHS or Xpress), or 
                    take the following steps to add support for a solver: 1) add the solver's Julia wrapper package to the project 
                    environment with the command ']add <package name>', 2) add package to using list in utils.jl, 
                    then 3) add code in function run_reopt_scenarios in utils.jl to create JuMP model with this optimizer.")
            end
            
            results = run_reopt(m, inputs)

            inputs["max_solve_time"] = max_solve_time
            inputs["optimality_gap_relative_tolerance"] = optimality_gap_relative_tolerance
            inputs["primal_feasibility_tolerance"] = primal_feasibility_tolerance
            inputs["dual_feasibility_tolerance"] = dual_feasibility_tolerance
            results["inputs"] = inputs
            open(results_filename(site_name=site_name, warming_plus_deg_C=plus_deg), "w") do f
                write(f, JSON.json(results))
            end
        end
    end
end

function summarize_and_plot_results(; sites::Vector{Dict{String,Any}}, warming_plus_deg_C::Vector{<:Real})
    for site in sites
        site_name = convert(String,site["name"])
        df_results_summary = DataFrame("Warming scenario" => ["Active cooling needed (MMBtu)", "Time actively cooling (%)", "PV size (W)", "Battery size (W)", "Battery size (Wh)", "LCC excluding thermosyphon (\$)", "Optimality gap (%)"])
        for plus_deg in warming_plus_deg_C
            plot_thermosyphon_series(site_name=site_name, warming_plus_deg_C=plus_deg)
            results = JSON.parsefile(results_filename(site_name=site_name, warming_plus_deg_C=plus_deg))
            df_results_summary = hcat(df_results_summary, DataFrame(
                    "+$(plus_deg)C" => [
                        round(results["Thermosyphon"]["min_annual_active_cooling_mmbtu"], digits=3),
                        round(count(i -> (i > 0), results["Thermosyphon"]["active_cooling_series_btu_per_hour"]) * 100 / 8760, digits=2),
                        round(results["PV"]["size_kw"]*1000, digits=1),
                        round(results["ElectricStorage"]["size_kw"]*1000, digits=1),
                        round(results["ElectricStorage"]["size_kwh"]*1000, digits=1),
                        round(results["Financial"]["lcc"], digits=0),
                        if typeof(results["optimality_gap"])<:Real round(results["optimality_gap"]*100, digits=2) else results["optimality_gap"] end
                    ]
            ))
        end
        CSV.write(joinpath("results","$(lowercase(site_name))_results_summary.csv"), df_results_summary)
    end
end

function plot_thermosyphon_series(; site_name::String, warming_plus_deg_C::Real)
    results_thermosyphon = JSON.parsefile(results_filename(site_name=site_name, warming_plus_deg_C=warming_plus_deg_C))["Thermosyphon"]
    plot(
        results_thermosyphon["electric_consumption_series_kw"],
        # markersize = 1,
        # linetype=:scatter,
        label="Power usage",
        xlabel = "Hour",
        ylabel="kW",
        # ylims = (-Inf, 0.07),
        left_margin = 5Plots.mm, 
        right_margin = 20Plots.mm,
        bottom_margin = 5Plots.mm,
        legend=:bottomleft
    )
    plot!(
        twinx(),
        results_thermosyphon["COP_series_mmbtu_per_kwh"],
        color=:red,
        xticks=:none,
        label="COP",
        ylabel="MMBtu/kWh",
        left_margin = 5Plots.mm, 
        right_margin = 15Plots.mm,
        legend=:bottomright
    )
    title = "Thermosyphon performance - $(site_name) with $(warming_plus_deg_C)C warming"
    plot!(
        title = title,
        size = (1000, 250)
    )
    savefig("results/$(title).png")
end

function BESS_kwh(; num_batteries, volts, amp_hours)
    return num_batteries * volts * amp_hours / 1000
end

function BESS_kw(; num_batteries, volts, max_amps)
    return num_batteries * volts * max_amps / 1000
end