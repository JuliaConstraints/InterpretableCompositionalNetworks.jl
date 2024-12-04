#=
"""
    generate_population(icn, pop_size
Generate a pôpulation of weights (individuals) for the genetic algorithm weighting `icn`.
"""
function generate_population(icn, pop_size)
    population = Vector{BitVector}()
    foreach(_ -> push!(population, falses(nbits(icn))), 1:pop_size)
    return population
end

"""
    _optimize!(icn, X, X_sols; metric = hamming, pop_size = 200)
Optimize and set the weights of an ICN with a given set of configuration `X` and solutions `X_sols`.
"""
function _optimize!(
    icn,
    solutions,
    non_sltns,
    dom_size,
    metric,
    pop_size,
    iterations;
    samples = nothing,
    memoize = false,
    parameters...,
)
    inplace = zeros(dom_size, max_icn_length())
    _non_sltns = isnothing(samples) ? non_sltns : rand(non_sltns, samples)

    function fitness(w)
        compo = compose(icn, w)
        f = composition(compo)
        S = Iterators.flatten((solutions, _non_sltns))
        σ = sum(
            x -> abs(f(x; X = inplace, dom_size, parameters...) - metric(x, solutions)),
            S,
        )
        return σ + regularization(icn) + weights_bias(w)
    end

    _fitness = memoize ? (@memoize Dict memoize_fitness(w) = fitness(w)) : fitness

    _icn_ga = GA(;
        populationSize = pop_size,
        crossoverRate = 0.8,
        epsilon = 0.05,
        selection = tournament(2),
        crossover = SPX,
        mutation = flip,
        mutationRate = 1.0,
    )

    pop = generate_population(icn, pop_size)
    r = Evolutionary.optimize(_fitness, pop, _icn_ga, Evolutionary.Options(; iterations))
    return weights!(icn, Evolutionary.minimizer(r))
end

"""
    optimize!(icn, X, X_sols, global_iter, local_iter; metric=hamming, popSize=100)
Optimize and set the weights of an ICN with a given set of configuration `X` and solutions `X_sols`. The best weights among `global_iter` will be set.
"""
function optimize!(
    icn,
    solutions,
    non_sltns,
    global_iter,
    iter,
    dom_size,
    metric,
    pop_size;
    sampler = nothing,
    memoize = false,
    parameters...,
)
    results = Dictionary{BitVector,Int}()
    aux_results = Vector{BitVector}(undef, global_iter)
    nt = Base.Threads.nthreads()

    @info """Starting optimization of weights$(nt > 1 ? " (multithreaded)" : "")"""
    samples = isnothing(sampler) ? nothing : sampler(length(solutions) + length(non_sltns))
    @qthreads for i = 1:global_iter
        @info "Iteration $i"
        aux_icn = deepcopy(icn)
        _optimize!(
            aux_icn,
            solutions,
            non_sltns,
            dom_size,
            eval(metric),
            pop_size,
            iter;
            samples,
            memoize,
            parameters...,
        )
        aux_results[i] = weights(aux_icn)
    end
    foreach(bv -> incsert!(results, bv), aux_results)
    best = rand(findall(x -> x == maximum(results), results))
    weights!(icn, best)
    return best, results
end

struct GeneticOptimizer <: AbstractOptimizer
    global_iter::Int
    local_iter::Int
    memoize::Bool
    pop_size::Int
    sampler::Union{Nothing,Function}
end

function GeneticOptimizer(;
    global_iter = Threads.nthreads(),
    local_iter = 64,
    memoize = false,
    pop_size = 64,
    sampler = nothing,
)
    return GeneticOptimizer(global_iter, local_iter, memoize, pop_size, sampler)
end

function CompositionalNetworks.optimize!(
    icn,
    solutions,
    non_sltns,
    dom_size,
    metric,
    optimizer::GeneticOptimizer;
    parameters...,
)
    return optimize!(
        icn,
        solutions,
        non_sltns,
        optimizer.global_iter,
        optimizer.local_iter,
        dom_size,
        metric,
        optimizer.pop_size;
        optimizer.sampler,
        optimizer.memoize,
        parameters...,
    )
end
=#

function generate_population(icn, pop_size)
	population = Vector{BitVector}()
	foreach(_ -> push!(population, falses(length(icn.weights))), 1:pop_size)
	return population
end

function optimize(
	icn::T,
	configurations::Configurations,
	# dom_size,
	metric_function::Function,
	population_size,
	iterations; samples = nothing, memoize = false, parameters...) where T <: AbstractICN

	# @info icn.weights
	
	# inplace = zeros(dom_size, 18)
	solution_iter = solutions(configurations)
	non_solutions = solutions(configurations; non_solutions=true)
	solution_vector = [i.x for i in solution_iter]
	
	function fitness(w)
		apply!(icn, w)
		return sum(
			x -> abs(evaluate(icn, x; parameters...) - metric_function(x.x, solution_vector)), configurations
		)
	end

	_icn_ga = GA(;
		populationSize = population_size,
		crossoverRate = 0.8,
		epsilon = 0.05,
		selection = tournament(2),
		crossover = SPX,
		mutation = flip,
		mutationRate = 1.0
	)

	pop = generate_population(icn, population_size)
	r = Evolutionary.optimize(fitness, pop, _icn_ga, Evolutionary.Options(; iterations))
	return apply!(icn, Evolutionary.minimizer(r))
end
