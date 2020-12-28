mutable struct ICN
    transformation::Layer
    arithmetic::Layer
    aggregation::Layer
    comparison::Layer
    weigths::BitVector

    function ICN(; nvars, dom_size,
        param=nothing,
        tr_layer=transformation_layer(param),
        ar_layer=arithmetic_layer(),
        ag_layer=aggregation_layer(),
        co_layer=comparison_layer(nvars, dom_size, param),
    )
        l = sum(
            layer -> _exclu(layer) ? _nbits_exclu(layer) : _length(layer),
            [tr_layer, ar_layer, ag_layer, co_layer]
        )
        new(tr_layer, ar_layer, ag_layer, co_layer, falses(l))
    end
end

_layers(icn) = [icn.transformation, icn.arithmetic, icn.aggregation, icn.comparison]
_length(icn::ICN) = sum(_length, _layers(icn))
_weigths(icn) = icn.weigths

_nbits_exclu(layer) = ceil(Int, log2(_length(layer)))

function compose(icn::ICN)
    funcs = Vector{Vector{Function}}()
    symbols = Vector{Vector{Symbol}}()

    _start = 0
    _end = 0

    for layer in _layers(icn)
        _start = _end + 1
        _end += _exclu(layer) ? _nbits_exclu(layer) : _length(layer)

        if _exclu(layer)
            f_id = _as_int(@view _weigths(icn)[_start:_end])
            f_id ≥ _length(layer) && return ((x...) -> 0.0)
            s = _symbol(layer, f_id + 1)
            push!(funcs, [_functions(layer)[s]])
            push!(symbols, [s])

        else
            !any(@view _weigths(icn)[_start:_end]) && return ((x...) -> 0.0)

            layer_funcs = Vector{Function}()
            layer_symbs = Vector{Symbol}()

            for (f_id, b) in enumerate(@view _weigths(icn)[_start:_end])
                if b
                    s = _symbol(layer, f_id)
                    push!(layer_funcs, _functions(layer)[s])
                    push!(layer_symbs, s)
                end
            end
            push!(funcs, layer_funcs)
            push!(symbols, layer_symbs)
        end
    end

    l = length(funcs[1])
    return x -> fill(x, l) .|> funcs[1] |> funcs[2][1] |> funcs[3][1] |> funcs[4][1]
end
