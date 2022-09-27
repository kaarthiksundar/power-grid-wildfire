function create_preventive_model(ref; budget::Int = 5, 
    load_factor::Float64 = 1.0,
    num_scenarios::Int = 10, 
    ramping_scaling::Float64 = 1.0, 
    load_shed_scaling::Float64 = 1.0, 
    decomposition_type = ScenarioDecomposition())

    scenarios = generate_scenarios(ref, num_scenarios)
    add_costs(ref, ramping_scaling, load_shed_scaling)
    var = Dict{Symbol,Any}()
    extra = Dict{Symbol,Any}()

    sp = StochasticProgram(scenarios, decomposition_type)

    @first_stage sp = begin 
        var[:z_branch] = @decision(sp, z_branch[l in keys(ref[:branch])], binary = true)
        var[:pg] = @decision(sp, 
            pg[i in keys(ref[:gen])], 
            lower_bound = 0.0, 
            upper_bound = ref[:gen][i]["pmax"]
        )
        var[:va] = @decision(sp, va[i in keys(ref[:bus])])
        var[:p] = @decision(sp, p[(l,i,j) in ref[:arcs_from]], 
            lower_bound = -ref[:branch][l]["rate_a"], 
            upper_bound = ref[:branch][l]["rate_a"]
        )
        p_expr = Dict([((l,i,j), 1.0 * p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
        p_expr = merge(p_expr, Dict([((l,j,i), -1.0 * p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))
        extra[:p_expr] = p_expr
        var[:p_dc] = @decision(sp, p_dc[a in ref[:arcs_dc]])
        
        for (l, dcline) in ref[:dcline]
            f_idx = (l, dcline["f_bus"], dcline["t_bus"])
            t_idx = (l, dcline["t_bus"], dcline["f_bus"])
    
            JuMP.set_lower_bound(p_dc[f_idx], dcline["pminf"])
            JuMP.set_upper_bound(p_dc[f_idx], dcline["pmaxf"])
    
            JuMP.set_lower_bound(p_dc[t_idx], dcline["pmint"])
            JuMP.set_upper_bound(p_dc[t_idx], dcline["pmaxt"])
        end
        
        @objective(sp, Min, sum(gen["cost"][1] * pg[i] for (i, gen) in ref[:gen]))
        
        for (i, _) in ref[:ref_buses]
            @constraint(sp, va[i] == 0)
        end
        
        for (i, _) in ref[:bus]
            # Build a list of the loads and shunt elements connected to the bus i
            bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]
    
            # Active power balance at node i
            @constraint(sp,
                sum(p_expr[a] for a in ref[:bus_arcs][i]) +             # sum of active power flow on lines from bus i +
                sum(p_dc[a_dc] for a_dc in ref[:bus_arcs_dc][i]) ==     # sum of active power flow on HVDC lines from bus i =
                sum(pg[g] for g in ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
                load_factor * sum(load["pd"] for load in bus_loads) -   # sum of active load consumption at bus i -
                sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          # sum of active shunt element injections at bus i
            )
        end

        for (i, branch) in ref[:branch]
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]
            f_idx = (i, f_bus, t_bus)
    
            _, b = calc_branch_y(branch)
    
            vad_min = ref[:off_angmin]
            vad_max = ref[:off_angmax]
    
            p_fr  = p[f_idx]
            va_fr = va[f_bus]
            va_to = va[t_bus]
            z = z_branch[i]
    
            if b <= 0
                @constraint(sp, p_fr <= -b * (va_fr - va_to + vad_max * (1-z)))
                @constraint(sp, p_fr >= -b * (va_fr - va_to + vad_min * (1-z)))
            else # account for bound reversal when b is positive
                @constraint(sp, p_fr >= -b * (va_fr - va_to + vad_max * (1-z)))
                @constraint(sp, p_fr <= -b * (va_fr - va_to + vad_min * (1-z)))
            end
    
            angmin = branch["angmin"]
            angmax = branch["angmax"]
    
            @constraint(sp, va_fr - va_to <= angmax*z + vad_max * (1-z))
            @constraint(sp, va_fr - va_to >= angmin*z + vad_min * (1-z))
    
            rate_a = branch["rate_a"]
            
            @constraint(sp, p_fr <=  rate_a * z)
            @constraint(sp, p_fr >= -rate_a * z)
        end 

        @constraint(sp, sum((1 - z_branch[i]) for i in keys(ref[:branch])) <= budget)
    end 

    @second_stage sp = begin 
        @known(sp, z_branch)
        @known(sp, pg)
        @uncertain ξ[(l,i,j) in ref[:arcs_from]] 

        var[:ramp_g_scenario] = @recourse(sp, 
            ramp_g_scenario[i in keys(ref[:gen])]
        )
        var[:ramp_g_plus_scenario] = @recourse(sp, 
            ramp_g_plus_scenario[i in keys(ref[:gen])], 
            lower_bound = 0.0,
            upper_bound = ref[:gen][i]["pmax"]
        )
        var[:ramp_g_minus_scenario] = @recourse(sp, 
            ramp_g_minus_scenario[i in keys(ref[:gen])], 
            lower_bound = 0.0,
            upper_bound = ref[:gen][i]["pmax"]
        )
        var[:load_scenario] = @recourse(sp, 
            load_scenario[i in keys(ref[:load])], 
            lower_bound = 0.0, 
            upper_bound = load_factor * ref[:load][i]["pd"]    
        )
        var[:va_scenario] = @recourse(sp, va_scenario[i in keys(ref[:bus])])
        var[:p_scenario] = @recourse(sp, p_scenario[(l,i,j) in ref[:arcs_from]], 
            lower_bound = -ref[:branch][l]["rate_a"], 
            upper_bound = ref[:branch][l]["rate_a"]
        )
        p_expr_scenario = Dict([((l,i,j), 1.0 * p_scenario[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
        p_expr_scenario = merge(p_expr_scenario, Dict([((l,j,i), -1.0 * p_scenario[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))
        extra[:p_expr_scenario] = p_expr_scenario
        var[:p_dc_scenario] = @recourse(sp, p_dc_scenario[a in ref[:arcs_dc]])
        for (l, dcline) in ref[:dcline]
            f_idx = (l, dcline["f_bus"], dcline["t_bus"])
            t_idx = (l, dcline["t_bus"], dcline["f_bus"])
    
            JuMP.set_lower_bound(p_dc_scenario[f_idx], dcline["pminf"])
            JuMP.set_upper_bound(p_dc_scenario[f_idx], dcline["pmaxf"])
    
            JuMP.set_lower_bound(p_dc_scenario[t_idx], dcline["pmint"])
            JuMP.set_upper_bound(p_dc_scenario[t_idx], dcline["pmaxt"])
        end
        # add ramping + load shedding costs
        JuMP.@objective(sp, Min, 
            sum((gen["cost"][1] + gen["ramping_cost"]) * ramp_g_plus_scenario[i] for (i, gen) in ref[:gen]) + 
            sum(gen["ramping_cost"] * ramp_g_minus_scenario[i] for (i, gen) in ref[:gen]) + 
            sum(load["shedding_cost"] * (load["pd"] * load_factor - load_scenario[i]) for (i, load) in ref[:load])
        )

        for (i, _) in ref[:ref_buses]
            @constraint(sp, va_scenario[i] == 0)
        end

        for (i, gen) in ref[:gen]
            @constraint(sp, ramp_g_scenario[i] == ramp_g_plus_scenario[i] - ramp_g_minus_scenario[i])
            @constraint(sp, pg[i] - ramp_g_minus_scenario[i] >= 0.0)
            @constraint(sp, pg[i] + ramp_g_plus_scenario[i] <= gen["pmax"])
        end     

        for (i, _) in ref[:bus]
            # Build a list of the shunt elements connected to the bus i
            bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]
    
            # Active power balance at node i
            @constraint(sp,
                sum(p_expr_scenario[a] for a in ref[:bus_arcs][i]) +             # sum of active power flow on lines from bus i +
                sum(p_dc_scenario[a_dc] for a_dc in ref[:bus_arcs_dc][i]) ==     # sum of active power flow on HVDC lines from bus i =
                sum(pg[g] + ramp_g_scenario[g] for g in ref[:bus_gens][i]) -     # sum of active power generation at bus i -
                sum(load_scenario[l] for l in ref[:bus_loads][i]) -              # sum of active load consumption at bus i -
                sum(shunt["gs"] for shunt in bus_shunts)*1.0^2                   # sum of active shunt element injections at bus i
            )
        end

        for (i, branch) in ref[:branch]
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]
            f_idx = (i, f_bus, t_bus)
    
            _, b = calc_branch_y(branch)
    
            vad_min = ref[:off_angmin]
            vad_max = ref[:off_angmax]
    
            p_fr  = p_scenario[f_idx]
            va_fr = va_scenario[f_bus]
            va_to = va_scenario[t_bus]
            z = z_branch[i]
    
            if b <= 0
                @constraint(sp, p_fr <= -b * (va_fr - va_to + vad_max * (1 - z * (1 - ξ[f_idx]))))
                @constraint(sp, p_fr >= -b * (va_fr - va_to + vad_min * (1 - z * (1 - ξ[f_idx]))))
            else # account for bound reversal when b is positive
                @constraint(sp, p_fr >= -b * (va_fr - va_to + vad_max * (1 - z * (1 - ξ[f_idx]))))
                @constraint(sp, p_fr <= -b * (va_fr - va_to + vad_min * (1 - z * (1 - ξ[f_idx]))))
            end
    
            angmin = branch["angmin"]
            angmax = branch["angmax"]
    
            @constraint(sp, va_fr - va_to <= angmax * z * (1 - ξ[f_idx]) + vad_max * (1 - z * (1 - ξ[f_idx])))
            @constraint(sp, va_fr - va_to >= angmin * z * (1 - ξ[f_idx]) + vad_min * (1 - z * (1 - ξ[f_idx])))
    
            rate_a = branch["rate_a"]
            
            @constraint(sp, p_fr <=  rate_a * z * (1 - ξ[f_idx]))
            @constraint(sp, p_fr >= -rate_a * z * (1 - ξ[f_idx]))
        end 
    end 

    return (model = sp, scenarios = scenarios, var = var, extra = extra)
end 


function set_pg_options(model, optimizer)
    set_optimizer(model, ProgressiveHedging.Optimizer)
    set_optimizer_attribute(model, SubProblemOptimizer(), optimizer)
    set_optimizer_attribute(model, Penalizer(), Adaptive())
    set_optimizer_attribute(model, PrimalTolerance(), 1e-3)
    set_optimizer_attribute(model, DualTolerance(), 1e-2)
    # set_optimizer_attribute(model, Execution(), Asynchronous())
end 

function solve_preventive_control_model(model, optimizer; method=:pg)
    if method == :pg 
        set_pg_options(model, optimizer)
        optimize!(model)
    else 
        @error "unknown solution algorithm for preventive control model"
    end 
    return
end 

function save_preventive_control_model_results(ref, cli_args, preventive_model, file::AbstractString)
    model = preventive_model.model 
    num_scenarios = cli_args["num_scenarios"]
    scenarios = preventive_model.scenarios
    load_factor = cli_args["load_weighting_factor"]
    pg = preventive_model.var[:pg]
    z_branch = preventive_model.var[:z_branch]
    
    scenarios_dictionary = Dict{String,Any}()
    for k in 1:num_scenarios 
        scenario = scenarios[k]
        data = scenario.data
        scenario_dict = Dict{String,Any}(string(l) => data.data[data.lookup[1][(l, i, j)]] for (l, i, j) in data.axes[1])
        scenarios_dictionary[string(k)] = [parse(Int32, i) for (i, val) in scenario_dict if val == 1.0]
    end     
    
    total_scenario_ramping_solution = Dict{String,Any}(
        "up_ramping" => Dict{String,Any}(
            string(i) => round(value.(model[2, :ramp_g_plus_scenario], i) |> vec |> sum; digits=4) for i in 1:num_scenarios
        ),
        "down_ramping" => Dict{String,Any}(
            string(i) => round(value.(model[2, :ramp_g_minus_scenario], i) |> vec |> sum; digits=4) for i in 1:num_scenarios
        )
    )
    
    gen_ramping_solution = Dict{String,Any}()
    for (i, _) in ref[:gen]
        up_ramping = [value(model[2, :ramp_g_plus_scenario][i], s) for s in 1:num_scenarios]
        down_ramping = [value(model[2, :ramp_g_minus_scenario][i], s) for s in 1:num_scenarios]
        total_up_ramping = up_ramping |> sum 
        total_down_ramping = down_ramping |> sum 
        (total_up_ramping > 0.0) && (gen_ramping_solution[string(i)] = up_ramping) 
        (total_down_ramping > 0.0) && (gen_ramping_solution[string(i)] = down_ramping) 
    end 

    total_load = [load_factor * load["pd"] for (_, load) in ref[:load]] |> sum 
    total_load_shed_solution = Dict{String,Any}(
        string(i) => (total_load - round(value.(model[2, :ramp_g_plus_scenario], i) |> vec |> sum; digits=4)) for i in 1:num_scenarios
    )
    
    load_shed_solution = Dict{String,Any}() 
    for (i, load) in ref[:load]
        pd = load_factor * load["pd"]
        load_shed = pd .- [round(value(model[2, :load_scenario][i], s); digits=4) for s in 1:num_scenarios]
        (load_shed |> sum > 0.0) && (load_shed_solution[string(i)] = load_shed)
    end 
     

    results = Dict{String,Any}(
        "num_scenarios" => num_scenarios, 
        "scenarios" => scenarios_dictionary,
        "termination_status" => JuMP.termination_status(model), 
        "objective_value" => round(JuMP.objective_value(model); digits=4),
        "solve_time" => round(JuMP.solve_time(model); digits=2),
        "num_iterations" => num_iterations(model.optimizer.optimizer),
        "costs" => Dict{String,Any}(
            "generation" => Dict{String,Any}(string(i) => gen["cost"][1] for (i, gen) in ref[:gen]), 
            "up_ramping" => Dict{String,Any}(string(i) => (gen["cost"][1] + gen["ramping_cost"]) for (i, gen) in ref[:gen]), 
            "down_ramping" => Dict{String,Any}(string(i) => gen["ramping_cost"] for (i, gen) in ref[:gen]), 
            "load_shedding_cost" => Dict{String,Any}(string(i) => load["shedding_cost"] for (i, load) in ref[:load]) 
        ),
        "base_generation" => Dict{String,Any}(string(i) => JuMP.value(pg[i]) for (i, _) in ref[:gen]),
        "off_branch" =>  [i[1] for i in eachindex(z_branch) if value(z_branch[i]) < 1e-6],
        "baseMVA" => ref[:baseMVA],
        "total_base_load" => round([load_factor * load["pd"] for (_, load) in ref[:load]] |> sum; digits=4),
        "total_base_generation" => round(value.(pg) |> vec |> sum; digits=4), 
        "total_base_shunt" => round([shunt["gs"] for (_, shunt) in ref[:shunt]] |> sum; digits=4),
        "generator_ramping" => gen_ramping_solution, 
        "total_scenario_ramping" => total_scenario_ramping_solution,
        "load_shed" => load_shed_solution, 
        "total_scenario_load_shed" => total_load_shed_solution
    )
    open(file, "w") do f
        write(f, JSON.json(results, 2))
    end
    return
end 