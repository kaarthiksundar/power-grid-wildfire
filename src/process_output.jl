using JSON 
using DelimitedFiles

function get_result_file_with_path()
    file_names = []
    preventive_path = "./output/no-threshold/preventive/"
    corrective_path = "./output/no-threshold/corrective/"
    for i in 20:20:200
        num_scenarios = string(i)
        serial_file = "budget_5_load_factor_" * 
            string(Int(1.00 * 100.0)) * "_serial" * 
            "_num_scenarios_" * num_scenarios * "_notopology.json"
        parallel_file = "budget_5_load_factor_" * 
            string(Int(1.00 * 100.0)) * "_parallel" * 
            "_num_scenarios_" * num_scenarios * "_notopology.json"
        push!(file_names, (
            1.00, 
            preventive_path * serial_file, corrective_path * serial_file, 
            preventive_path * parallel_file, corrective_path * parallel_file)
        )
    end 
    for i in 20:20:200
        num_scenarios = string(i)
        serial_file = "budget_5_load_factor_" * 
            string(Int(1.05 * 100.0)) * "_serial" * 
            "_num_scenarios_" * num_scenarios * "_notopology.json"
        parallel_file = "budget_5_load_factor_" * 
            string(Int(1.05 * 100.0)) * "_parallel" * 
            "_num_scenarios_" * num_scenarios * "_notopology.json"
        push!(file_names, (
            1.05, 
            preventive_path * serial_file, corrective_path * serial_file, 
            preventive_path * parallel_file, corrective_path * parallel_file)
        )
    end
    return file_names
end 

function get_solve_stats(files; parallel::Bool = false)
    results = []
    for (lf, s_p, s_c, p_p, p_c) in files 
        (!isfile(s_p) || !isfile(s_c) || !isfile(p_p) || !isfile(p_c)) && (continue)
        s_p_data = JSON.parsefile(s_p)
        s_c_data = JSON.parsefile(s_c)
        if parallel
            p_p_data = JSON.parsefile(p_p)
            p_c_data = JSON.parsefile(p_c)
        end 

        s_p_obj = s_p_data["objective_value"]
        s_c_obj = s_c_data["objective_value"]
        s_rel_gap = trunc((s_p_obj - s_c_obj)/s_c_obj * 100.0; digits=2)
        if parallel 
            p_p_obj = p_p_data["objective_value"]
            p_c_obj = p_c_data["objective_value"]
            p_rel_gap = trunc((p_p_obj - p_c_obj)/p_c_obj * 100.0; digits=2)
        end 
        
        if parallel
            prev_rel_gap = trunc(abs(s_p_obj - p_p_obj)/s_p_obj * 100.0; digits=2)
            corr_rel_gap = trunc(abs(s_c_obj - p_c_obj)/s_c_obj * 100.0; digits=2)
        end

        s_p_time = s_p_data["solve_time"]
        s_c_time = s_c_data["solve_time"]
        if parallel
            p_p_time = p_p_data["solve_time"]
            p_c_time = p_c_data["solve_time"]
        end 

        s_p_iter = s_p_data["num_iterations"] |> Int
        s_c_iter = s_c_data["num_iterations"] |> Int
        if parallel
            p_p_iter = p_p_data["num_iterations"] |> Int
            p_c_iter = p_c_data["num_iterations"] |> Int
        end 

        row = Vector{Union{Float64,Int}}()
        
        push!(row, trunc(lf, digits=2))
        push!(row, s_p_data["num_scenarios"] |> Int)
        
        if parallel 
            append!(row, [s_p_time, p_p_time, s_c_time, p_c_time])
        else 
            append!(row, [s_p_time, s_c_time])
        end

        append!(row, [s_p_obj, s_c_obj, s_rel_gap])
        (parallel) && (append!(row, [p_p_obj, p_c_obj, p_rel_gap]))
        (parallel) && (append!(row, [prev_rel_gap, corr_rel_gap]))

        if parallel 
            append!(row, [s_p_iter, p_p_iter])
            append!(row, [s_c_iter, p_c_iter])
        else 
            append!(row, [s_p_iter, s_c_iter])
        end 

        push!(results, row)
    end 
    return results
end 

function write_csv(file, header, rows)
    open(file, "w") do io
        writedlm(io, [permutedims(header); reduce(hcat, rows)'], ',')
    end
end 

function process_solution(; parallel::Bool = false)
    files = get_result_file_with_path()
    rows = get_solve_stats(files; parallel = parallel)
    if (parallel)
        header = ["load factor", "# scenarios", 
        "serial prev. time", "parallel prev. time", 
        "serial corr. time", "parallel corr. time", 
        "serial prev. obj. val.", "serial corr. obj. val.", "serial obj. rel. gap.", 
        "parallel prev. obj. val.", "parallel corr. obj. val.", "parallel obj. rel. gap.", 
        "prev. ser. to par. rel. gap", "corr. ser. to par. rel. gap", 
        "serial prev. iter.", "parallel prev. iter.", 
        "serial corr. iter.", "parallel corr. iter."]
    else 
        header = ["load factor", "# scenarios", 
        "serial prev. time", 
        "serial corr. time", 
        "serial prev. obj. val.", "serial corr. obj. val.", "serial obj. rel. gap.", 
        "serial prev. iter.",
        "serial corr. iter."]
    end
    write_csv("./output/solution_stats_no_threshold.csv", header, rows)
end 