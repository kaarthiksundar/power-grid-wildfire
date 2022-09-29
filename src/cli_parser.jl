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
            default = "corrective"
        "--switch_budget", "-b"
            help = "number of lines that can be turned off in the topology control problem"
            arg_type = Int 
            default = 5
        "--num_scenarios", "-s"
            help = "number of scenarios used for stochastic program"
            arg_type = Int 
            default = 100
        "--load_weighting_factor", "-l"
            help = "weighting factor for loads" 
            arg_type = Float64 
            default = 1.05
        "--result_folder", "-r"
            help = "folder to save the results"
            arg_type = String 
            default = "./output/"
    end

    return parse_args(s)
end

get_cli_args() = parse_cli_args()