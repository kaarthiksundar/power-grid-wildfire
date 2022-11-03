using Distributed

num_procs = trunc(Int, Sys.CPU_THREADS * 0.50)
addprocs(num_procs)

@everywhere using Pkg
@everywhere Pkg.activate(".")

@everywhere using Pipe 
@everywhere using ArgParse 
@everywhere using PowerModels
@everywhere using JuMP
@everywhere using CPLEX 
@everywhere using StochasticPrograms
@everywhere import JSON

include("cli_parser.jl")

input_cli_args = get_cli_args()
cli_args = map(k -> "$k -> $(input_cli_args[k])\n", keys(input_cli_args) |> collect) 

for arg in cli_args 
    @info arg
end 

for w in workers()
    # Do not log on worker nodes
    remotecall(()->global_logger(NullLogger()),w)
end


function create_result_file_with_path(input_cli_args)
    result_folder = input_cli_args["result_folder"] * input_cli_args["model"]
    (!isdir(result_folder)) && (mkdir(result_folder))
    serial_parallel = (input_cli_args["parallel"]) ? "_parallel" : "_serial"
    use_topology = (input_cli_args["use_topology_solution"]) ? "_topology" : "_notopology"
    num_scenarios = (input_cli_args["model"] != "topology") ? string(input_cli_args["num_scenarios"]) : "0"
    file = "budget_" * string(input_cli_args["switch_budget"]) * 
        "_load_factor_" * string(Int(input_cli_args["load_weighting_factor"] * 100.0)) * 
        serial_parallel *  "_num_scenarios_" * num_scenarios * use_topology * ".json"
    return result_folder * "/" * file
end 

function get_topology_control_off_branches(input_cli_args)
    (input_cli_args["use_topology_solution"] == false) && (return [])
    result_folder = input_cli_args["result_folder"] * "topology"
    file = "budget_" * string(input_cli_args["switch_budget"]) * 
        "_load_factor_" * string(Int(input_cli_args["load_weighting_factor"] * 100.0)) * 
        "_serial_num_scenarios_0_notopology.json"
    full_file = result_folder * "/" * file 
    if isfile(full_file)
        data = open(full_file, "r") do io
            JSON.parse(io, dicttype=Dict)
        end
        @info "reading from topology control solution successfull; branches that are off: $(data["off_branch"])"
        return data["off_branch"]
    else 
        @info "reading from topology control solution failed due to non-existence of file, continuing solve without initial state"
        return []
    end 
end 

PowerModels.silence()
milp_optimizer = JuMP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput" => 0)

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
    result_file = create_result_file_with_path(input_cli_args)
    save_topology_control_model_results(ref, input_cli_args, topology_control_model, result_file)
    @pipe "output written to $result_file.\n" |> printstyled(_, color = :cyan)
    return topology_control_model
end 

function run_preventive_control_model(ref, input_cli_args)
    scenariofile = input_cli_args["scenariofile"]
    method = (input_cli_args["lshaped"]) ? Symbol("lshaped") : Symbol("pg")
    off_branches = get_topology_control_off_branches(input_cli_args)
    result_file = create_result_file_with_path(input_cli_args)
    (isfile(result_file)) && (@info "result file exists... quitting"; return)
    preventive_model = create_preventive_model(ref; 
        budget = input_cli_args["switch_budget"], 
        num_scenarios = input_cli_args["num_scenarios"], 
        off_branches = off_branches, parallel = input_cli_args["parallel"], 
        scenariofile = scenariofile, load_factor = input_cli_args["load_weighting_factor"],
        pg = (method == :pg))
    printstyled("solving preventive control model with budget...\n", color = :red)
    solve_preventive_control_model(preventive_model.model, milp_optimizer, input_cli_args, method = method)
    save_preventive_control_model_results(ref, input_cli_args, preventive_model, off_branches, result_file)
    @pipe "output written to $result_file.\n" |> printstyled(_, color = :cyan)
    return preventive_model
end 

function run_corrective_control_model(ref, input_cli_args)
    scenariofile = input_cli_args["scenariofile"]
    off_branches = get_topology_control_off_branches(input_cli_args)
    result_file = create_result_file_with_path(input_cli_args)
    (isfile(result_file)) && (@info "result file exists... quitting"; return)
    corrective_model = create_corrective_model(ref; 
        budget = input_cli_args["switch_budget"], 
        num_scenarios = input_cli_args["num_scenarios"],
        off_branches = off_branches, parallel = input_cli_args["parallel"], 
        scenariofile = scenariofile, load_factor = input_cli_args["load_weighting_factor"])
    printstyled("solving corrective control model with budget...\n", color = :red)
    solve_corrective_control_model(corrective_model.model, milp_optimizer, input_cli_args)
    save_corrective_control_model_results(ref, input_cli_args, corrective_model, off_branches, result_file)
    @pipe "output written to $result_file.\n" |> printstyled(_, color = :cyan)
    return corrective_model
end 

ref = parse_case_data(input_cli_args["datafile"]) |> get_ref

(input_cli_args["model"] == "topology") && (run_base_model(ref, input_cli_args))
(input_cli_args["model"] == "preventive") && (run_preventive_control_model(ref, input_cli_args))
(input_cli_args["model"] == "corrective") && (run_corrective_control_model(ref, input_cli_args)) 
printstyled("solve complete", color = :cyan)