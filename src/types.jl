struct OptModel 
    model::JuMP.AbstractModel
    var::Dict{Symbol,Any}
    extra::Dict{Symbol,Any}
    solution::Dict{Symbol,Any}
end 

OptModel()::OptModel = OptModel(JuMP.Model(), Dict{Symbol,Any}(), Dict{Symbol,Any}(), Dict{Symbol,Any}())

struct StochasticOptModel
    model::StochasticModel 
    var::Dict{Symbol,Any}
    extra::Dict{Symbol,Any}
    solution::Dict{Symbol,Any}
    scenarios::Vector{Scenario}
end 
