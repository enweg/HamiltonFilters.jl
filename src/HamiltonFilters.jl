module HamiltonFilters

import Base: filter
using DataFrames

export HamiltonFilter, filter

"""
    HamiltonFilter(h::Int, p::Int)

A struct for the Hamilton (2018) filter, which decomposes a time series
into trend and cycle components by regressing ``y_{t+h}`` on
``(1, y_t, y_{t-1}, \\dots, y_{t-p+1})``. The parameter `h` is the
forecast horizon; `p` is the number of most recent values at time ``t``
(including ``y_t``, so it uses `p-1` lags).

# Arguments

- `h::Int`: Forecast horizon.
- `p::Int`: Number of most recent values used at time ``t``.

# References

Hamilton, J. D. (2018). "Why You Should Never Use the Hodrick-Prescott
Filter." *The Review of Economics and Statistics*, 100(5), 831–843.
https://doi.org/10.1162/rest_a_00706
"""
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

"""
    filter(hfilter::HamiltonFilter, data::Vector{<:Real})

Applies the Hamilton filter to a univariate time series. Returns a tuple
containing the estimated trend and cyclical components. Due to filtering,
the first `(p-1) + h` observations are lost and filled with `NaN`.

# Arguments

- `hfilter::HamiltonFilter`: A `HamiltonFilter` instance.
- `data::Vector{<:Real}`: A vector of real-valued observations.

# Returns

- `(trend::Vector, cycle::Vector)`: A pair of vectors of the same length
  as `data`.
"""
function filter(hfilter::HamiltonFilter, data::Vector{T}) where {T<:Real}
    trend = fill(T(NaN), length(data))
    cycle = fill(T(NaN), length(data))
    trend_, cycle_ = _hamilton_filter(data, hfilter.h, hfilter.p)
    trend[(hfilter.p+hfilter.h):end] .= trend_
    cycle[(hfilter.p+hfilter.h):end] .= cycle_
    return trend, cycle
end

"""
    filter(hfilter::HamiltonFilter, data::Union{Matrix{<:Real},DataFrame})

Applies the Hamilton filter column-wise to a multivariate dataset. Returns
the estimated trend and cyclical components for each column. Due to
filtering, the first `(p-1) + h` observations in each column are lost and
filled with `NaN`.

# Arguments
- `hfilter::HamiltonFilter`: A `HamiltonFilter` instance.
- `data::Union{Matrix{<:Real}, DataFrame}`: A matrix or DataFrame with
  real-valued columns.

# Returns
- `(trend, cycle)`: Two matrices or DataFrames of the same size as `data`.
"""
function filter(
    hfilter::HamiltonFilter, 
    data::Union{Matrix{<:Real},DataFrame}
)

    trend = similar(data)
    cycle = similar(data)

    for i in axes(data, 2)
        col = data[:, i]
        eltype(col) <: Real || throw(ArgumentError("Column is not Real"))
        trend[:, i], cycle[:, i] = filter(hfilter, col)
    end
    return trend, cycle
end

end
