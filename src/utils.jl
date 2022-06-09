using JuMP
using Xpress
using REopt
using DataFrames
import JSON
import CSV


function results_filename(; site, plus_deg)
    if plus_deg == 0
        plus_deg_string = ""
    else
        plus_deg_string = "_plus$(plus_deg)C"
    end
    return "results/thermosyphon_results_$(lowercase(site["name"]))$(plus_deg_string).json"
end

function run_reopt_scenarios(; sites, warming_plus_deg_C, 
                            BESS_size_kwh, BESS_size_kw, 
                            BESS_capx_cost_per_kwh, 
                            PV_capx_cost_per_kw, 
                            PV_om_cost_per_kw_per_year,
                            maxtime=3600,
                            relstop=1e-6,
                            gapstop=1e-6,
                            primalstop=1e-6)
    PV_prod_factor_col_name = "ProdFactor"
    temp_deg_C_col_name = "TempC"

    inputs = JSON.parsefile(joinpath("data","thermosyphon_scenario.json"))
    if !("loads_kw" in inputs["ElectricLoad"])
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
        for plus_deg in warming_plus_deg_C
            inputs["Site"]["longitude"] = site["longitude"]
            inputs["Site"]["latitude"] = site["latitude"]
            weather_file = CSV.File(joinpath("data","$(lowercase(site["name"]))_weather.csv"))
            prod_factor =  getproperty(weather_file,Symbol(PV_prod_factor_col_name))
            amb_temp_degF =  (getproperty(weather_file,Symbol(temp_deg_C_col_name)) .+ plus_deg) .* 1.8 .+ 32
            inputs["PV"]["prod_factor_series"] = prod_factor
            inputs["Thermosyphon"]["ambient_temp_degF"] = amb_temp_degF

            m = Model(()->Xpress.Optimizer(MAXTIME=-maxtime, MIPRELSTOP=relstop, BARGAPSTOP=gapstop, BARPRIMALSTOP=primalstop))
            m = Model(()->HiGHS.Optimizer(MAXTIME=-maxtime, MIPRELSTOP=relstop, BARGAPSTOP=gapstop, BARPRIMALSTOP=primalstop))
            set_optimizer_attribute(model, "time_limit", 60.0)

            results = run_reopt(m, inputs)

            inputs["MAXTIME"] = maxtime
            inputs["MIPRELSTOP"] = relstop
            inputs["BARGAPSTOP"] = gapstop
            inputs["BARPRIMALSTOP"] = primalstop
            results["inputs"] = inputs
            open(results_filename(site=site, plus_deg=plus_deg), "w") do f
                write(f, JSON.json(results))
            end
        end
    end
end

function summarize_results(; sites, warming_plus_deg_C)
    for site in sites
        df_results_summary = DataFrame("Warming scenario" => ["Active cooling needed (MMBtu)", "PV size (W)", "Battery size (W)", "Battery size (Wh)", "Time actively cooling (%)", "Optimality gap (%)"])
        for plus_deg in warming_plus_deg_C
            results = JSON.parsefile(results_filename(site=site, plus_deg=plus_deg))
            df_results_summary = hcat(df_results_summary, DataFrame(
                    "+$(plus_deg)C" => [
                        round(results["Thermosyphon"]["min_annual_active_cooling_mmbtu"], digits=3),
                        results["PV"]["size_kw"]*1000,
                        results["ElectricStorage"]["size_kw"]*1000,
                        results["ElectricStorage"]["size_kwh"]*1000,
                        round(count(i -> (i > 0), results["Thermosyphon"]["active_cooling_series_btu_per_hour"]) * 100 / 8760, digits=2),
                        if typeof(results["optimality_gap"])<:Real round(results["optimality_gap"]*100, digits=2) else results["optimality_gap"] end
                    ]
            ))
        end
        CSV.write(joinpath("results","$(lowercase(site["name"]))_results_summary.csv", df_results_summary))
    end
end

function BESS_kwh(; num_batteries, volts, amp_hours)
    return num_batteries * volts * amp_hours / 1000
end

function BESS_kw(; num_batteries, volts, max_amps)
    return num_batteries * volts * max_amps / 1000
end