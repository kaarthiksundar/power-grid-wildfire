function parse_cli_args()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--datafile"
            help = "case file name with full path (relative to project's  root directory)"
            arg_type = String 
            default = "./data/RTS_GMLC.m"
        "--model", "-m"
            help = "topology/preventive/corrective"
            arg_type = String 
            default = "preventive"
        "--use_topology_solution", "-u"
            help = "flag to use the solution from deterministic topology control as initial state for preventive/corrective model" 
            action = :store_true
        "--switch_budget", "-b"
            help = "number of lines that can change state when performing topology control"
            arg_type = Int 
            default = 5
        "--num_scenarios", "-s"
            help = "number of scenarios used for stochastic program"
            arg_type = Int 
            default = 2
        "--load_weighting_factor", "-l"
            help = "weighting factor for loads" 
            arg_type = Float64 
            default = 1.05
        "--result_folder", "-r"
            help = "folder to save the results"
            arg_type = String 
            default = "./output/"
        "--parallel"
            help = "flag for parallel run"
            action = :store_true
    end

    return parse_args(s)
end

get_cli_args() = parse_cli_args()