using ArgParse
using PowerModels
using StatsBase 
using JSON
using Random 

Random.seed!(2022)

PowerModels.silence()

include("data_parser.jl")

function parse_cli_args()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--datafile"
            help = "case file name with full path (relative to project's  root directory)"
            arg_type = String 
            default = "./data/RTS_GMLC.m"
        "--num_scenarios", "-s"
            help = "number of scenarios used for stochastic program"
            arg_type = Int 
            default = 200
        "--num_line_outages", "-n"
            help = "maximum number of lines outages"
            arg_type = Int 
            default = 3
        "--threshold_risk", "-r"
            help = "flag to threshold risk (lower bound)"
            action = :store_true
        "--threshold_risk_value", "-t"
            help = "threshold risk value at"
            arg_type = Float64 
            default = 3.0
    end
    return parse_args(s)
end

function generate_scenarios(args)
    @show args
    datafile = args["datafile"]
    threshold = ""
    (args["threshold_risk"]) && (threshold = "threshold")
    scenariofile = replace(datafile, ".m" => "_scenarios_" * threshold * ".json")
    (isfile(scenariofile)) && (@info "scenario file exists."; return)
    num_scenarios = args["num_scenarios"]
    num_line_outages = args["num_line_outages"]
    
    # scenario generation 
    scenarios = Dict{String,Any}()
    ref = parse_case_data(args["datafile"]) |> get_ref
    ids = ref[:arcs_from]
    if args["threshold_risk"]
        for (_, branch) in ref[:branch]
            (branch["power_risk"] <= args["threshold_risk_value"]) && (branch["power_risk"] = 0.0)
        end 
        # non_zero_risk_lines = [l for (l, _, _) in ids if ref[:branch][l]["power_risk"] != 0.0][1:3]
        # for (l, branch) in ref[:branch]
        #     if !(l in non_zero_risk_lines)
        #         branch["power_risk"] = 0.0
        #     end 
        # end 
    end 
    
    non_zero_risk_lines = [l for (l, _, _) in ids if ref[:branch][l]["power_risk"] != 0.0]
    num_non_zero_risk_lines = non_zero_risk_lines |> length
    println("non-zero risk lines: $non_zero_risk_lines" )
    println("num non-zero risk lines: $num_non_zero_risk_lines")
    total_risk = [ref[:branch][l]["power_risk"] for (l, _, _) in ids] |> sum 
    for (_, branch) in ref[:branch]
        branch["prob"] = branch["power_risk"]/total_risk
    end 
    weights = [ref[:branch][l]["prob"] for (l, _, _) in ids]

    num_scenarios_created = -1
    scenarios[string(num_scenarios_created += 1)] = []
    
    for _ in 1:num_scenarios 
        samples = StatsBase.sample(ids, Weights(weights), num_line_outages) |> unique!
        scenarios[string(num_scenarios_created += 1)] = map(x -> first(x), samples)
    end 

    open(scenariofile, "w") do f
        write(f, JSON.json(scenarios, 2))
    end
    
    return 
end 


args = parse_cli_args()
generate_scenarios(args)
