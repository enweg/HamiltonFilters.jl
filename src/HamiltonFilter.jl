module HamiltonFilters

# TODO: test and publish

import Base: filter
using DataFrames

export HamiltonFilter, filter

struct HamiltonFilter
    h::Int
    p::Int
end

function _hamilton_filter(data::AbstractVector{T}, h::Int, p::Int) where {T<:Real}
    n = length(data)
    rows = p:(n - h)

    X = ones(T, length(rows), p + 1)
    for i in 0:(p-1)
        X[:, i+2] .= @view data[rows .- i]
    end

    y = @view data[rows .+ h]

    β = X \ y
    trend = X * β
    cycle = y .- trend

    return trend, cycle
end

function filter(hfilter::HamiltonFilter, data::AbstractVector)
    return _hamilton_filter(data, hfilter.h, hfilter.p)
end
function filter(hfilter::HamiltonFilter, data::Union{AbstractMatrix,DataFrame})
    trend = similar(data)
    cycle = similar(data)

    for (i, col) in enumerate(eachcol(data))
        trend[:, i], cycle[:, i] = filter(hfilter, col)
    end
    return trend, cycle
end

end
