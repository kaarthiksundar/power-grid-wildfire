function create_preventive_model(ref; budget::Int = 5)

    var = Dict{Symbol,Any}()
    extra = Dict{Symbol,Any}()

    @stochastic_model m begin 
        @stage 1 begin 
            z_branch = var[:z_branch] = @decision(m, [l in keys(ref[:branch])], binary = true)
            pg = var[:pg] = @decision(m, 
                [i in keys(ref[:gen])], 
                lower_bound = ref[:gen][i]["pmin"], 
                upper_bound = ref[:gen][i]["pmax"]
            )
            va = var[:va] = @decision(m, va[i in keys(ref[:bus])])
            p = var[:p] = @decision(m, [(l,i,j) in ref[:arcs_from]], 
                lower_bound = -ref[:branch][l]["rate_a"], 
                upper_bound = ref[:branch][l]["rate_a"]
            )
            p_expr = Dict([((l,i,j), 1.0 * p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
            p_expr = merge(p_expr, Dict([((l,j,i), -1.0 * p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))
            extra[:p_expr] = p_expr
            p_dc = var[:p_dc] = @decision(m, [a in ref[:arcs_dc]])
            
            for (l, dcline) in ref[:dcline]
                f_idx = (l, dcline["f_bus"], dcline["t_bus"])
                t_idx = (l, dcline["t_bus"], dcline["f_bus"])
        
                JuMP.set_lower_bound(p_dc[f_idx], dcline["pminf"])
                JuMP.set_upper_bound(p_dc[f_idx], dcline["pmaxf"])
        
                JuMP.set_lower_bound(p_dc[t_idx], dcline["pmint"])
                JuMP.set_upper_bound(p_dc[t_idx], dcline["pmaxt"])
            end
            
            @objective(m, Min, sum(gen["cost"][1] * pg[i] for (i, gen) in ref[:gen]))
            
            for (i, _) in ref[:ref_buses]
                @constraint(m, va[i] == 0)
            end
            
            for (i, _) in ref[:bus]
                # Build a list of the loads and shunt elements connected to the bus i
                bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
                bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]
        
                # Active power balance at node i
                @constraint(m,
                    sum(p_expr[a] for a in ref[:bus_arcs][i]) +             # sum of active power flow on lines from bus i +
                    sum(p_dc[a_dc] for a_dc in ref[:bus_arcs_dc][i]) ==     # sum of active power flow on HVDC lines from bus i =
                    sum(pg[g] for g in ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
                    sum(load["pd"] for load in bus_loads) -                 # sum of active load consumption at bus i -
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
                    @constraint(m, p_fr <= -b * (va_fr - va_to + vad_max * (1-z)))
                    @constraint(m, p_fr >= -b * (va_fr - va_to + vad_min * (1-z)))
                else # account for bound reversal when b is positive
                    @constraint(m, p_fr >= -b * (va_fr - va_to + vad_max * (1-z)))
                    @constraint(m, p_fr <= -b * (va_fr - va_to + vad_min * (1-z)))
                end
        
                angmin = branch["angmin"]
                angmax = branch["angmax"]
        
                @constraint(m, va_fr - va_to <= angmax*z + vad_max * (1-z))
                @constraint(m, va_fr - va_to >= angmin*z + vad_min * (1-z))
        
                rate_a = branch["rate_a"]
                
                @constraint(m, p_fr <=  rate_a * z)
                @constraint(m, p_fr >= -rate_a * z)
            end 

            @constraint(m, sum((1 - z_branch[i]) for i in keys(ref[:branch])) <= budget)
        end 

        @stage 2 begin 
            @uncertain ξ[(l,i,j) in ref[:arcs_from]] 
            ramp_g_scenario = var[:ramp_g_scenario] = @recourse(m, 
                [i in keys(ref[:gen])], 
                lower_bound = ref[:gen][i]["pmin"], 
                upper_bound = ref[:gen][i]["pmax"]
            )
            t_g_scenario = var[:t_g_scenario] = @recourse(m, 
                [i in keys(ref[:gen])], 
                lower_bound = 0.0,
                upper_bound = ref[:gen][i]["pmax"]
            )
            load_shed_scenario = var[:load_shed_scenario] = @recourse(m, 
                [i in keys(ref[:load])], 
                lower_bound = 0.0, 
                upper_bound = ref[:load][i]["pd"]    
            )
            va_scenario = var[:va_scenario] = @recourse(m, va[i in keys(ref[:bus])])
            p_scenario = var[:p_scenario] = @recourse(m, [(l,i,j) in ref[:arcs_from]], 
                lower_bound = -ref[:branch][l]["rate_a"], 
                upper_bound = ref[:branch][l]["rate_a"]
            )
            p_expr_scenario = Dict([((l,i,j), 1.0 * p_scenario[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
            p_expr_scenario = merge(p_expr_scenario, Dict([((l,j,i), -1.0 * p_scenario[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))
            extra[:p_expr_scenario] = p_expr_scenario
            p_dc_scenario = var[:p_dc_scenario] = @recourse(m, [a in ref[:arcs_dc]])
            
            for (l, dcline) in ref[:dcline]
                f_idx = (l, dcline["f_bus"], dcline["t_bus"])
                t_idx = (l, dcline["t_bus"], dcline["f_bus"])
        
                JuMP.set_lower_bound(p_dc_scenario[f_idx], dcline["pminf"])
                JuMP.set_upper_bound(p_dc_scenario[f_idx], dcline["pmaxf"])
        
                JuMP.set_lower_bound(p_dc_scenario[t_idx], dcline["pmint"])
                JuMP.set_upper_bound(p_dc_scenario[t_idx], dcline["pmaxt"])
            end

        end 
    end 


    """
    # add objective cost;model is always 2 and order is always 1 (data has been fixed to give zero constant)
    JuMP.@objective(m, Min, sum(gen["cost"][1] * pg[i] for (i, gen) in ref[:gen]))

    # fix the voltage angle to zero at the reference bus
    for (i, _) in ref[:ref_buses]
        JuMP.@constraint(m, va[i] == 0)
    end

    # nodal power balance constraints
    for (i, _) in ref[:bus]
        # Build a list of the loads and shunt elements connected to the bus i
        bus_loads = [ref[:load][l] for l in ref[:bus_loads][i]]
        bus_shunts = [ref[:shunt][s] for s in ref[:bus_shunts][i]]

        # Active power balance at node i
        JuMP.@constraint(m,
            sum(p_expr[a] for a in ref[:bus_arcs][i]) +             # sum of active power flow on lines from bus i +
            sum(p_dc[a_dc] for a_dc in ref[:bus_arcs_dc][i]) ==     # sum of active power flow on HVDC lines from bus i =
            sum(pg[g] for g in ref[:bus_gens][i]) -                 # sum of active power generation at bus i -
            sum(load["pd"] for load in bus_loads) -                 # sum of active load consumption at bus i -
            sum(shunt["gs"] for shunt in bus_shunts)*1.0^2          # sum of active shunt element injections at bus i
        )
    end

    # ohms law on-off version + voltage difference on-off version + thermal limit on-off 
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
            JuMP.@constraint(m, p_fr <= -b * (va_fr - va_to + vad_max * (1-z)))
            JuMP.@constraint(m, p_fr >= -b * (va_fr - va_to + vad_min * (1-z)))
        else # account for bound reversal when b is positive
            JuMP.@constraint(m, p_fr >= -b * (va_fr - va_to + vad_max * (1-z)))
            JuMP.@constraint(m, p_fr <= -b * (va_fr - va_to + vad_min * (1-z)))
        end

        angmin = branch["angmin"]
        angmax = branch["angmax"]

        JuMP.@constraint(m, va_fr - va_to <= angmax*z + vad_max * (1-z))
        JuMP.@constraint(m, va_fr - va_to >= angmin*z + vad_min * (1-z))

        rate_a = branch["rate_a"]
        
        JuMP.@constraint(m, p_fr <=  rate_a * z)
        JuMP.@constraint(m, p_fr >= -rate_a * z)
    end 

    # budget constraints on line switching
    JuMP.@constraint(m, sum((1 - z_branch[i]) for i in keys(ref[:branch])) <= budget)
    """
    # return opt_model
end 

# function solve_topology_control_model(opt_model::OptModel, optimizer)
#     JuMP.set_optimizer(opt_model.model, optimizer)
#     JuMP.optimize!(opt_model.model)
#     opt_model.solution[:termination_status] = JuMP.termination_status(opt_model.model)
#     opt_model.solution[:objective] = round(JuMP.objective_value(opt_model.model); digits=4)
#     return
# end 