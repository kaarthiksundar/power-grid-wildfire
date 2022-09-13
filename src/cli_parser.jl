function parse_cli_args()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--datafile"
            help = "case file name with full path (relative to project's  root directory)"
            arg_type = String 
            default = "./data/RTS_GMLC.m"
        "--model", "-m"
            help = "preventive/corrective"
            arg_type = String 
            default = "preventive"
    end

    return parse_args(s)
end

get_cli_args() = parse_cli_args()