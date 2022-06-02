using JuMP
using Xpress
using REopt
using DataFrames
import JSON
import CSV

function results_filename(site, plus_deg)
    if plus_deg == 0
        plus_deg_string = ""
    else
        plus_deg_string = "_plus$(plus_deg)C"
    end
    return "results/thermosyphon_results_$(lowercase(site["name"]))$(plus_deg_string).json"
end

function run_reopt_scenarios()
    PV_prod_factor_col_name = "ProdFactor"
    temp_deg_C_col_name = "TempC"

    inputs = JSON.parsefile("data/thermosyphon_scenario.json")
    inputs["ElectricLoad"]["loads_kw"] = zeros(8760)
    inputs["ElectricStorage"]["min_kw"] = size_kw
    inputs["ElectricStorage"]["max_kw"] = size_kw
    inputs["ElectricStorage"]["min_kwh"] = size_kwh
    inputs["ElectricStorage"]["max_kwh"] = size_kwh
    inputs["ElectricStorage"]["installed_cost_per_kw"] = 0
    inputs["ElectricStorage"]["installed_cost_per_kwh"] = cost_kwh
    inputs["ElectricStorage"]["replace_cost_per_kw"] = 0
    inputs["ElectricStorage"]["replace_cost_per_kwh"] = cost_kwh
    inputs["ElectricStorage"]["inverter_replacement_year"] = 10
    inputs["ElectricStorage"]["battery_replacement_year"] = 10

    for site in sites
        # df_results_summary = DataFrame("Warming scenario" => ["Active cooling needed (MMBtu)", "PV size (W)", "Battery size (W)", "Battery size (Wh)"])
        for plus_deg in plus_deg_C_variations
            inputs["Site"]["longitude"] = site["longitude"]
            inputs["Site"]["latitude"] = site["latitude"]
            weather_file = CSV.File("data/$(lowercase(site["name"]))_weather.csv")
            prod_factor =  getproperty(weather_file,Symbol(PV_prod_factor_col_name))
            amb_temp_degF =  (getproperty(weather_file,Symbol(temp_deg_C_col_name)) .+ plus_deg) .* 1.8 .+ 32
            inputs["PV"]["prod_factor_series"] = prod_factor
            inputs["Thermosyphon"]["ambient_temp_degF"] = amb_temp_degF

            global m = Model(()->Xpress.Optimizer(MAXTIME=-maxtime, MIPRELSTOP=relstop, BARGAPSTOP=gapstop, BARPRIMALSTOP=primalstop))
            global m = Model(()->HiGHS.Optimizer(MAXTIME=-maxtime, MIPRELSTOP=relstop, BARGAPSTOP=gapstop, BARPRIMALSTOP=primalstop))
            set_optimizer_attribute(model, "time_limit", 60.0)

            results = run_reopt(m, inputs)

            inputs["MAXTIME"] = maxtime
            inputs["MIPRELSTOP"] = relstop
            inputs["BARGAPSTOP"] = gapstop
            inputs["BARPRIMALSTOP"] = primalstop
            results["inputs"] = inputs
            open(results_filename(site, plus_deg), "w") do f
                write(f, JSON.json(results))
            end
        end
    end
end

function summarize_results()
    for site in sites
        df_results_summary = DataFrame("Warming scenario" => ["Active cooling needed (MMBtu)", "PV size (W)", "Battery size (W)", "Battery size (Wh)", "Time actively cooling (%)", "Optimality gap (%)"])
        for plus_deg in plus_deg_C_variations
            results = JSON.parsefile(results_filename(site, plus_deg))
            df_results_summary = hcat(df_results_summary, DataFrame(
                    "+$(plus_deg)C" => [
                        round(results["Thermosyphon"]["min_annual_active_cooling_mmbtu"], digits=3),
                        round(results["PV"]["size_kw"]*1000, digits=0),
                        round(results["ElectricStorage"]["size_kw"]*1000, digits=0),
                        round(results["ElectricStorage"]["size_kwh"]*1000, digits=0),
                        round(count(i -> (i > 0), results["Thermosyphon"]["active_cooling_series_btu_per_hour"]) * 100 / 8760, digits=2),
                        if typeof(results["optimality_gap"])<:Real round(results["optimality_gap"]*100, digits=2) else results["optimality_gap"] end
                    ]
            ))
        end
        CSV.write("results/$(lowercase(site["name"]))_results_summary.csv", df_results_summary)
    end
end

