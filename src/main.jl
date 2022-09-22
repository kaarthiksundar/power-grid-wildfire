using Pipe 
using ArgParse 
using PowerModels
using JuMP
using CPLEX 
using StatsBase
using StochasticPrograms

PowerModels.silence()
milp_optimizer = JuMP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput" => 0)


include("cli_parser.jl")
include("data_parser.jl")
include("types.jl")
include("scenario_generation.jl")
include("topology_control.jl")
include("preventive.jl")

input_cli_args = get_cli_args()
cli_args = map(k -> "$k -> $(input_cli_args[k])", keys(input_cli_args) |> collect) 

@pipe "CLI arguments: $cli_args\n" |> printstyled(_, color = :cyan)

ref = parse_case_data(input_cli_args["datafile"]) |> get_ref

if input_cli_args["model"] == "topology"
    topology_control_model = create_topology_control_model(ref; budget = input_cli_args["switch_budget"])
    printstyled("solving topology control model with budget...\n", color = :red)
    solve_topology_control_model(topology_control_model, milp_optimizer)
    @pipe "status: $(topology_control_model.solution[:termination_status]), obj: $(topology_control_model.solution[:objective])\n" |> printstyled(_, color = :cyan)
elseif input_cli_args["model"] == "preventive"
    preventive_model = create_preventive_model(ref; budget = input_cli_args["switch_budget"], num_scenarios = 5)
    printstyled("solving preventive control model with budget...\n", color = :red)
    solve_preventive_control_model(preventive_model.model, milp_optimizer, :pg)
else 
    @warn "not implemented"
end 

