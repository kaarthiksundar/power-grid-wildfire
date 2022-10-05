function parse_json(file_string::AbstractString)
    data = open(file_string, "r") do io
        parse_json(io)
    end
    return data
end

function parse_json(io::IO)
    data = JSON.parse(io, dicttype=Dict)
    return data
end

function generate_scenarios(ref, num_scenarios::Int, datafile; no_wildfire_probability::Float64 = 0.0)
    (~isfile(datafile)) && (@error "scenario file does not exist")
    data = parse_json(datafile)
    ids = ref[:arcs_from]

    scenario_probability = (1-no_wildfire_probability)/float(num_scenarios)
    scenarios = AbstractScenario[]
    # push!(scenarios, @scenario ξ[id in ids] = [0.0 for id in ids] probability = no_wildfire_probability)
    for i in 1:num_scenarios
        samples = map(x -> (x, ref[:branch][x]["f_bus"], ref[:branch][x]["t_bus"]), data[string(i)])        
        scenario = @scenario ξ[id in ids] = [(id in samples) ? 1.0 : 0.0 for id in ids] probability = scenario_probability 
        push!(scenarios, scenario)
    end 
    return scenarios
end 