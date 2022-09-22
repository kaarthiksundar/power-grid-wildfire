function parse_case_data(file)
    data = PowerModels.parse_file(file)

    # linear regression to find cost
    for (_, gen) in get(data, "gen", [])
        (gen["model"] != 1) && (continue)
        pg = gen["cost"][1:2:end]
        cost = gen["cost"][2:2:end]
        best_slope = sum(pg .* cost) / sum(pg.^2)
        gen["model"] = 2
        gen["cost"] = [best_slope/100.0, 0.0] 
        gen["ncost"] = 2
    end 
    
    # standarize polynomial costs
    PowerModels.standardize_cost_terms!(data, order=1)

    # Adds reasonable rate_a values to branches without them
    PowerModels.calc_thermal_limits!(data)
    return data
end 

function get_ref(data)
    ref = PowerModels.build_ref(data)
    PowerModels.ref_add_on_off_va_bounds!(ref, data)
    return ref[:it][:pm][:nw][0]
end 

function add_costs(ref, ramp_scaling, load_shed_scaling) 
    for (_, gen) in ref[:gen]
        gen["ramping_cost"] = ramp_scaling * gen["cost"][1] * 0.01
    end
    max_generation_cost = [gen["cost"][1] for (_, gen) in ref[:gen]] |> maximum
    for (_, load) in ref[:load]
        load["shedding_cost"] = load_shed_scaling * max_generation_cost * 10.0
    end 
end 