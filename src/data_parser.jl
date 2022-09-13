function parse_case_data(file)
    data = PowerModels.parse_file(file)

    # linear regression to find cost
    for (_, gen) in get(data, "gen", [])
        (gen["model"] != 1) && (continue)
        pg = gen["cost"][1:2:end]
        cost = gen["cost"][2:2:end]
        best_slope = sum(pg .* cost) / sum(pg.^2)
        gen["model"] = 2
        gen["cost"] = [best_slope, 0.0] 
        gen["ncost"] = 2
    end 
    
    # standarize polynomial costs
    PowerModels.standardize_cost_terms!(data, order=1)

    # Adds reasonable rate_a values to branches without them
    PowerModels.calc_thermal_limits!(data)
    return data
end 