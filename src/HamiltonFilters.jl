module HamiltonFilters

# TODO: test and publish

import Base: filter
using DataFrames

export HamiltonFilter, filter

struct HamiltonFilter
    h::Int
    p::Int
end

function _hamilton_filter(data::Vector{T}, h::Int, p::Int) where {T<:Real}
    n = length(data)
    rows = p:n

    X = ones(T, length(rows), p + 1)
    for i in 0:(p-1)
        X[:, i+2] .= @view data[rows .- i]
    end
    X_train = @view X[1:(end-h), :]

    rows = p:(n - h)
    y = @view data[rows .+ h]

    β = X_train \ y
    trend = (X * β)[1:(end-h)]
    cycle = data[(p+h):end] .- trend

    return trend, cycle
end

function filter(hfilter::HamiltonFilter, data::Vector{T}) where {T<:Real}
    trend = fill(T(NaN), length(data))
    cycle = fill(T(NaN), length(data))
    trend_, cycle_ = _hamilton_filter(data, hfilter.h, hfilter.p)
    trend[(hfilter.p+hfilter.h):end] .= trend_
    cycle[(hfilter.p+hfilter.h):end] .= cycle_
    return trend, cycle
end
function filter(
    hfilter::HamiltonFilter, 
    data::Union{Matrix{<:Real},DataFrame}
)

    trend = similar(data)
    cycle = similar(data)

    for (i, col) in enumerate(eachcol(data))
        eltype(col) <: Real || throw(ArgumentError("Column is not Real"))
        trend[:, i], cycle[:, i] = filter(hfilter, col)
    end
    return trend, cycle
end

end
