"""
    _generate_population(icn, pop_size
Generate a pôpulation of weigths (individuals) for the genetic algorithm weigthing `icn`.
"""
function _generate_population(icn, pop_size)
    population = Vector{BitVector}()
    foreach(_ -> push!(population, falses(_nbits(icn))), 1:pop_size)
    return population
end

"""
    _loss(X, X_sols, icn, weigths, metric)
Compute the loss of `icn`.
"""
function _loss(X, X_sols, icn, weigths, metric)
    f = compose(icn, weigths)
    return sum(x -> abs(f(x) - metric(x, X_sols)), X) + regularization(icn)
end

"""
    _optimize!(icn, X, X_sols; metric = hamming, pop_size = 200)
Optimize and set the weigths of an ICN with a given set of configuration `X` and solutions `X_sols`.
"""
function _optimize!(icn, X, X_sols; metric=hamming, pop_size=200, iter=100)
    fitness = weigths -> _loss(X, X_sols, icn, weigths, metric)

    _icn_ga = GA(
        populationSize=pop_size,
        crossoverRate=0.8,
        epsilon=0.05,
        selection=tournament(2),
        crossover=singlepoint,
        mutation=flip,
        mutationRate=1.0
    )

    pop = _generate_population(icn, pop_size)
    res = optimize(fitness, pop, _icn_ga, Options(iterations=iter))
    _weigths!(icn, minimizer(res))
end

"""
    optimize!(icn, X, X_sols, global_iter, local_iter; metric=hamming, popSize=100)
Optimize and set the weigths of an ICN with a given set of configuration `X` and solutions `X_sols`. The best weigths among `global_iter` will be set. 
"""

function optimize!(icn, X, X_sols, global_iter, local_iter; metric=hamming, popSize=100)
    results = Dictionary{BitVector,Int}()
    @info "Starting optimization of weights"
    for i in 1:global_iter
        @info "Iteration $i"
        _optimize!(icn, X, X_sols; iter = local_iter, metric = metric, pop_size = popSize)
        _incsert!(results, _weigths(icn))
    end
    best = rand(findall(x -> x == maximum(results), results))
    _weigths!(icn, best)
    @info show_composition(icn) best results
    return best, results
end
