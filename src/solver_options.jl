function set_pg_options(model, optimizer)
    set_optimizer(model, ProgressiveHedging.Optimizer)
    set_optimizer_attribute(model, SubProblemOptimizer(), optimizer)
    set_optimizer_attribute(model, Penalizer(), Adaptive())
    set_optimizer_attribute(model, PrimalTolerance(), 1e-3)
    set_optimizer_attribute(model, DualTolerance(), 1e-2)
    # set_optimizer_attribute(model, Execution(), Asynchronous())
end 