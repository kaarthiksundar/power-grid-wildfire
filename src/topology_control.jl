function create_topology_control_model(ref; budget::Int = 5)::OptModel 
    opt_model = OptModel() 
    m = opt_model.model 
    var = opt_model.var 
    extra = opt_model.extra

    # topology variables for the lines 
    z_branch = var[:z_branch] = JuMP.@variable(m, [l in keys(ref[:branch])], binary = true)

    # real power generation variables for the generators with limits 
    pg = var[:pg] = JuMP.@variable(m, 
        [i in keys(ref[:gen])], 
        lower_bound = ref[:gen][i]["pmin"], 
        upper_bound = ref[:gen][i]["pmax"]
    )

    # Add voltage angles va for each bus
    va = var[:va] = JuMP.@variable(m, va[i in keys(ref[:bus])])
    # note: [i in keys(ref[:bus])] adds one `va` variable for each bus in the network

    # real power flow variables on the lines with limits 
    p = var[:p] = JuMP.@variable(m, [(l,i,j) in ref[:arcs_from]], 
        lower_bound = -ref[:branch][l]["rate_a"], 
        upper_bound = ref[:branch][l]["rate_a"]
    )

    # build JuMP expressions for the value of p[(l,i,j)] and p[(l,j,i)] on the branches
    p_expr = Dict([((l,i,j), 1.0 * p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]])
    p_expr = merge(p_expr, Dict([((l,j,i), -1.0 * p[(l,i,j)]) for (l,i,j) in ref[:arcs_from]]))
    extra[:p_expr] = p_expr
    # note: this is used to make the definition of nodal power balance simpler

    # real power flow variables p_dc to represent the active power flow for each HVDC line
    p_dc = var[:p_dc] = JuMP.@variable(m, [a in ref[:arcs_dc]])

    for (l, dcline) in ref[:dcline]
        f_idx = (l, dcline["f_bus"], dcline["t_bus"])
        t_idx = (l, dcline["t_bus"], dcline["f_bus"])

        JuMP.set_lower_bound(p_dc[f_idx], dcline["pminf"])
        JuMP.set_upper_bound(p_dc[f_idx], dcline["pmaxf"])

        JuMP.set_lower_bound(p_dc[t_idx], dcline["pmint"])
        JuMP.set_upper_bound(p_dc[t_idx], dcline["pmaxt"])
    end

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
    """
    `-b*(t[f_bus] - t[t_bus] + vad_min*(1-z_branch[i])) <= p[f_idx] <= -b*(t[f_bus] - t[t_bus] + vad_max*(1-z_branch[i]))`
    `angmin*z_branch[i] + vad_min*(1-z_branch[i]) <= t[f_bus] - t[t_bus] <= angmax*z_branch[i] + vad_max*(1-z_branch[i])`
    `-z_branch[i]*rate_a <= p[f_idx] <= z_branch[i]*rate_a`
    """
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

    return opt_model
end 

function solve_topology_control_model(opt_model::OptModel, optimizer)
    JuMP.set_optimizer(opt_model.model, optimizer)
    JuMP.optimize!(opt_model.model)
    opt_model.solution[:termination_status] = JuMP.termination_status(opt_model.model)
    opt_model.solution[:objective] = round(JuMP.objective_value(opt_model.model); digits=4)
    return
end 