# Thermosyphon_REopt_Analysis

# Installing code dependencies
The Julia dependencies can be installed within Julia. See https://julialang.org/downloads to get the latest Julia version. Then run the following from this repository's top directory:
```julia
julia --project=.
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.7.2 (2022-02-06)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> import Pkg

julia> Pkg.instantiate()
```

# REopt Inputs
The master branch of [REopt.jl package](https://github.com/NREL/REopt.jl) has [online documentation](https://nrel.github.io/REopt.jl/dev/) (you can also find the documentation linked in the Github repository README.md). [REopt inputs](https://nrel.github.io/REopt.jl/dev/reopt/inputs/) are provided either from a JSON file or a Julia dictionary. Note that if we removed a technology key from the JSON file then this technology would not be evaluated.

The file data/thermosyphon_scenario.json contains the base set of inputs to be used for an analysis sizing PV with BESS to supply a thermosyphon. For an off-grid system, the `"ElectricUtility"` inputs `outage_start_time_step` and `outage_end_time_step` are set to 1 and 8760 respectively, and the inputs provided in `"ElectricTariff"` aren't used.

This repository uses a [custom branch](https://github.com/NREL/REopt.jl/tree/alaska_thermosyphon) of the REopt.jl package that includes a thermosyphon model. By including the `"Thermosyphon"` key, a thermosyphon will be included in the optimization, using default values for any inputs not provided. 
Possible inputs for the [thermosyphon model](https://github.com/NREL/REopt.jl/blob/alaska_thermosyphon/src/core/thermosyphon.jl) are:
| Name                                                    | Type            | Default       |
|--------------------------------------------------------:|----------------:|--------------:|
| `ambient_temp_degF`                                     | Array{<:Real,1} | TMY profile   |
| `ground_temp_degF`                                      | Real            | 25            |
| `passive_to_active_cutoff_temp_degF`                    | Real            | 20            |
| `effective_conductance_btu_per_degF`                    | Real            | 141           |
| `fixed_active_cooling_rate_kw`                          | Real            | 0.345         |
| `COP_curve_points_ambient_temp_degF`                    | Array{<:Real,1} | [46, 52, 63]  |
| `COP_curve_points_coefficient_of_performance_kw_per_kw` | Array{<:Real,1} | [9, 6, 3]     |
| `structure_heat_to_ground_mmbtu_per_year`               | Real            | 5.9           |
Thermosyphon coefficient of performance can be modeled as a flat value by providing a single value for `COP_curve_points_coefficient_of_performance_kw_per_kw`. Alternatively, COP can be modeled as a piecewise function, defined by a list of points. In this case, `COP_curve_points_ambient_temp_degF` and `COP_curve_points_coefficient_of_performance_kw_per_kw` are the temperature and COP values respectively of those points. Defaults for these are used when neither input is provided.

# Running Julia code
The file src/main.jl is this project's main script to run analyses of DERs to supply a thermosyphon. This script defines sites and climate warming scenarios to run, chosen BESS size and cost, and optimization parameters to balance precision and solve time. The script then runs REopt for these scenarios, which each produces a JSON file of results. Finally, key results are summarized in CSV for each site. Modify src/main.jl and data/thermosyphon_scenario.json as desired and then run the following from this repository's top directory:
```julia
julia --project=.
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.7.2 (2022-02-06)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |


julia> include("src/main.jl")
```
