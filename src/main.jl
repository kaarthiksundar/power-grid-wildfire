using Distributed

addprocs(20)

@everywhere using Pkg
@everywhere Pkg.activate(".")

@everywhere using Pipe 
@everywhere using ArgParse 
@everywhere using PowerModels
@everywhere using JuMP
@everywhere using CPLEX 
@everywhere using StatsBase
@everywhere using StochasticPrograms
@everywhere import JSON



@everywhere using Random
@everywhere Random.seed!(2022)

for w in workers()
    # Do not log on worker nodes
    remotecall(()->global_logger(NullLogger()),w)
end

PowerModels.silence()
milp_optimizer = JuMP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput" => 0)


include("cli_parser.jl")
include("data_parser.jl")
include("types.jl")
include("scenario_generation.jl")
include("topology_control.jl")
include("solver_options.jl")
include("preventive.jl")
include("corrective.jl")

function run_base_model(ref, input_cli_args)
    topology_control_model = create_topology_control_model(ref; budget = input_cli_args["switch_budget"], load_factor = input_cli_args["load_weighting_factor"])
    printstyled("solving topology control model with budget...\n", color = :red)
    solve_topology_control_model(topology_control_model, milp_optimizer)
    result_folder = input_cli_args["result_folder"] * input_cli_args["model"]
    (!isdir(result_folder)) && (mkdir(result_folder))
    result_file = result_folder * "/budget_" * string(input_cli_args["switch_budget"]) * "_load_factor_" * string(Int(input_cli_args["load_weighting_factor"] * 100.0)) * ".json"
    save_topology_control_model_results(ref, input_cli_args, topology_control_model, result_file)
    @pipe "output written to $result_file.\n" |> printstyled(_, color = :cyan)
    return topology_control_model
end 

function run_preventive_control_model(ref, input_cli_args)
    preventive_model = create_preventive_model(ref; budget = input_cli_args["switch_budget"], num_scenarios = input_cli_args["num_scenarios"])
    printstyled("solving preventive control model with budget...\n", color = :red)
    solve_preventive_control_model(preventive_model.model, milp_optimizer)
    result_folder = input_cli_args["result_folder"] * input_cli_args["model"]
    (!isdir(result_folder)) && (mkdir(result_folder))
    result_file = result_folder * "/budget_" * string(input_cli_args["switch_budget"]) * 
        "_load_factor_" * string(Int(input_cli_args["load_weighting_factor"] * 100.0)) * 
        "_num_scenarios_" * string(input_cli_args["num_scenarios"]) * ".json"
    save_preventive_control_model_results(ref, input_cli_args, preventive_model, result_file)
    @pipe "output written to $result_file.\n" |> printstyled(_, color = :cyan)
    return preventive_model
end 

function run_corrective_control_model(ref, input_cli_args)
    corrective_model = create_corrective_model(ref; budget = input_cli_args["switch_budget"], num_scenarios = input_cli_args["num_scenarios"])
    printstyled("solving corrective control model with budget...\n", color = :red)
    solve_corrective_control_model(corrective_model.model, milp_optimizer)
    result_folder = input_cli_args["result_folder"] * input_cli_args["model"]
    (!isdir(result_folder)) && (mkdir(result_folder))
    result_file = result_folder * "/budget_" * string(input_cli_args["switch_budget"]) * 
        "_load_factor_" * string(Int(input_cli_args["load_weighting_factor"] * 100.0)) * 
        "_num_scenarios_" * string(input_cli_args["num_scenarios"]) * ".json"
    save_corrective_control_model_results(ref, input_cli_args, corrective_model, result_file)
    @pipe "output written to $result_file.\n" |> printstyled(_, color = :cyan)
    return corrective_model
end 


input_cli_args = get_cli_args()
cli_args = map(k -> "$k -> $(input_cli_args[k])", keys(input_cli_args) |> collect) 

@pipe "CLI arguments: $cli_args\n" |> printstyled(_, color = :cyan)

ref = parse_case_data(input_cli_args["datafile"]) |> get_ref

(input_cli_args["model"] == "topology") && (run_base_model(ref, input_cli_args))
(input_cli_args["model"] == "preventive") && (run_preventive_control_model(ref, input_cli_args))
(input_cli_args["model"] == "corrective") && (run_corrective_control_model(ref, input_cli_args)) 
printstyled("solve complete", color = :cyan)