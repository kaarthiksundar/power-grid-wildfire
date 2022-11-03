function set_pg_options(model, optimizer; parallel::Bool = false)
    StochasticPrograms.set_optimizer!(model.optimizer, ProgressiveHedging.Optimizer)
    set_optimizer_attribute(model, SubProblemOptimizer(), optimizer)
    set_optimizer_attribute(model, Penalizer(), Adaptive())
    set_optimizer_attribute(model, PrimalTolerance(), 1e-3)
    set_optimizer_attribute(model, DualTolerance(), 1e-2)
    (parallel) && (set_optimizer_attribute(model, Execution(), Asynchronous()))
end 

function set_lshaped_options(model, optimizer; parallel::Bool = false)
    StochasticPrograms.set_optimizer!(model.optimizer, LShaped.Optimizer)
    set_optimizer_attribute(model, SubProblemOptimizer(), optimizer)
    set_optimizer_attribute(model, MasterOptimizer(), optimizer)
    set_optimizer_attribute(model, FeasibilityStrategy(), FeasibilityCuts())
    set_optimizer_attribute(model, Regularizer(), LV())
    set_optimizer_attribute(model, RelativeTolerance(), 1e-2)
    set_optimizer_attribute(model, Aggregator(), ClusterAggregate(Kmedoids(20, distance = angular_distance))) # Use K-medoids cluster aggregation
    set_optimizer_attribute(model, Consolidator(), Consolidate())
    (parallel) && (set_optimizer_attribute(model, Execution(), Asynchronous()))
end 