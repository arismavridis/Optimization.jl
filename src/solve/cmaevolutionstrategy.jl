export CMAEvolutionStrategyOpt
struct CMAEvolutionStrategyOpt end

function __map_optimizer_args(prob::OptimizationProblem, opt::CMAEvolutionStrategyOpt;
    cb=nothing,
    maxiters::Union{Number, Nothing}=nothing,
    maxtime::Union{Number, Nothing}=nothing, 
    abstol::Union{Number, Nothing}=nothing, 
    reltol::Union{Number, Nothing}=nothing, 
    kwargs...)

    if !isnothing(reltol)
        @warn "common reltol is currently not used by $(opt)"
    end

    mapped_args = (;lower = prob.lb,
    upper = prob.ub,
    kwargs...)
  
    if !isnothing(maxiters)
        mapped_args = (; mapped_args..., maxiter=maxiters)
    end

    if !isnothing(maxtime)
        mapped_args = (; mapped_args..., maxtime=maxtime)
    end

    if !isnothing(abstol)
        mapped_args = (; mapped_args..., ftol=abstol)
    end
  
    return mapped_args
end


function __solve(prob::OptimizationProblem, opt::CMAEvolutionStrategyOpt, data = DEFAULT_DATA;
                 cb = (args...) -> (false), 
                 maxiters::Union{Number, Nothing} = nothing,
                 maxtime::Union{Number, Nothing} = nothing,
                 abstol::Union{Number, Nothing}=nothing,
                 reltol::Union{Number, Nothing}=nothing,
                 progress = false, kwargs...)
    local x, cur, state

    if data != DEFAULT_DATA
        maxiters = length(data)
    end

    cur, state = iterate(data)

    function _cb(trace)
        cb_call = cb(decompose_trace(trace).metadata["x"],trace.value...)
        if !(typeof(cb_call) <: Bool)
            error("The callback should return a boolean `halt` for whether to stop the optimization process.")
        end
        cur, state = iterate(data, state)
        cb_call
    end

    maxiters = _check_and_convert_maxiters(maxiters)
    maxtime = _check_and_convert_maxtime(maxtime)

    _loss = function(θ)
        x = prob.f(θ, prob.p, cur...)
        return first(x)
    end

    opt_args = _map_optimizer_args(prob, opt, cb=_cb, maxiters=maxiters, maxtime=maxtime,abstol=abstol, reltol=reltol; kwargs...)

    t0 = time()
    opt_res = CMAEvolutionStrategy.minimize(_loss, prob.u0, 0.1; opt_args...)
    t1 = time()

    opt_ret = opt_res.stop.reason

    SciMLBase.build_solution(prob, opt, opt_res.logger.xbest[end], opt_res.logger.fbest[end]; original=opt_res, retcode=opt_ret)
end