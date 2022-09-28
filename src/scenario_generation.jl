function generate_scenarios(ref, num_scenarios::Int; num_line_outages::Int = 5, no_wildfire_probability::Float64 = 0.0)
    ids = ref[:arcs_from]
    total_risk = [ref[:branch][l]["power_risk"] for (l, _, _) in ids] |> sum 
    for (_, branch) in ref[:branch]
        branch["prob"] = branch["power_risk"]/total_risk
    end 
    weights = [ref[:branch][l]["prob"] for (l, _, _) in ids]

    scenario_probability = (1-no_wildfire_probability)/float(num_scenarios)
    scenarios = AbstractScenario[]
    # push!(scenarios, @scenario ξ[id in ids] = [0.0 for id in ids] probability = no_wildfire_probability)
    for _ in 1:num_scenarios
        samples = StatsBase.sample(ids, Weights(weights), num_line_outages, replace=false)        
        scenario = @scenario ξ[id in ids] = [(id in samples) ? 1.0 : 0.0 for id in ids] probability = scenario_probability 
        push!(scenarios, scenario)
    end 
    return scenarios
end 