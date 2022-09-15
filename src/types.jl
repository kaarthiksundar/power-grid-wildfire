struct OptModel 
    model::JuMP.AbstractModel
    var::Dict{Symbol,Any}
    extra::Dict{Symbol,Any}
    solution::Dict{Symbol,Any}
end 

OptModel()::OptModel = OptModel(JuMP.Model(), Dict{Symbol,Any}(), Dict{Symbol,Any}(), Dict{Symbol,Any}())