using Pipe 
using ArgParse 
using PowerModels

include("cli_parser.jl")
include("data_parser.jl")

input_cli_args = get_cli_args()
cli_args = map(k -> "$k -> $(input_cli_args[k])", keys(input_cli_args) |> collect) 

@pipe "CLI arguments: $cli_args\n" |> printstyled(_, color = :cyan)

data = parse_case_data(input_cli_args["datafile"])