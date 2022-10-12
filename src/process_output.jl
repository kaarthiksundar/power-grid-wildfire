using JSON 
using DelimitedFiles

function get_result_file_with_path(parallel::Bool)
    file_names = []
    preventive_path = "./output/preventive/"
    corrective_path = "./output/corrective/"
    serial_parallel = (parallel) ? "_parallel" : "_serial"
    for i in 20:20:200
        num_scenarios = string(i)
        file = "budget_5_load_factor_" * 
            string(Int(1.00 * 100.0)) * serial_parallel * 
            "_num_scenarios_" * num_scenarios * "_notopology.json"
        push!(file_names, (1.00, preventive_path * file, corrective_path * file))
    end 
    for i in 20:20:200
        num_scenarios = string(i)
        file = "budget_5_load_factor_" * 
            string(Int(1.05 * 100.0)) * serial_parallel * 
            "_num_scenarios_" * num_scenarios * "_notopology.json"
        push!(file_names, (1.05, preventive_path * file, corrective_path * file))
    end
    return file_names
end 

function get_solve_stats(files)
    results = []
    for (lf, preventive, corrective) in files 
        preventive_data = JSON.parsefile(preventive)
        corrective_data = JSON.parsefile(corrective)
        preventive_obj = preventive_data["objective_value"]
        corrective_obj = corrective_data["objective_value"]
        rel_gap = (preventive_obj - corrective_obj)/corrective_obj * 100.0
        row = Vector{Union{Float64,Int}}()
        push!(row, trunc(lf, digits=2))
        push!(row, preventive_data["num_scenarios"] |> Int)
        push!(row, preventive_data["objective_value"])
        push!(row, preventive_data["num_iterations"] |> Int)
        push!(row, preventive_data["solve_time"]) 
        push!(row, corrective_data["objective_value"])
        push!(row, corrective_data["num_iterations"])
        push!(row, corrective_data["solve_time"]) 
        push!(row, trunc(rel_gap, digits=2))
        push!(results, row)
    end 
    return results
end 

function write_csv(file, header, rows)
    open(file, "w") do io
        writedlm(io, [permutedims(header); reduce(hcat, rows)'], ',')
    end
end 

function process_solution(;parallel::Bool=false)
    files = get_result_file_with_path(parallel)
    rows = get_solve_stats(files)
    header = ["load factor", "# scenarios", "preventive obj. val.", "preventive iter.", "preventive time",
        "corrective obj. val.", "corrective iter.", "corrective time", "obj. rel. gap"]
    write_csv("./output/solution_stats.csv", header, rows)
end 