module HamiltonFilters

using DataFrames

export HamiltonFilter, apply

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

function _is_invalid_row(x::AbstractVector)
    return any(ismissing.(x)) || any(isnan.(x)) || any(isinf.(x))
end
function _is_invalid_row(x::Union{Missing,Number})
    return ismissing(x) || isnan(x) || isinf(x)
end

function _hamilton_filter(data::Vector{T}, h::Int, p::Int) where {T<:Union{Missing,<:Real}}
    n = length(data)
    rows = p:n

    X = ones(T, length(rows), p + 1)
    for i in 0:(p-1)
        X[:, i+2] .= @view data[rows.-i]
    end
    X_train = @view X[1:(end-h), :]

    rows = p:(n-h)
    y = @view data[rows.+h]

    X_invalid_rows = map(row -> _is_invalid_row(row), eachrow(X_train))
    y_invalid_rows = _is_invalid_row.(y)
    invalid_rows = X_invalid_rows .|| y_invalid_rows

    X_train = @view X_train[(!).(invalid_rows), :]
    y = @view y[(!).(invalid_rows)]

    β = X_train \ y
    trend = (X*β)[1:(end-h)]
    cycle = data[(p+h):end] .- trend

    return trend, cycle
end

_hfilter_padding(h::Int, p::Int, ::Type{T}) where {T<:AbstractFloat} =
    fill(T(NaN), h + p - 1)
_hfilter_padding(h::Int, p::Int, ::Type{Union{Missing,T}}) where {T<:Number} =
    fill(missing, h + p - 1)
_hfilter_padding(::Int, ::Int, ::Type{T}) where {T<:Any} =
    throw(ArgumentError("No padding type exists for this input. Try to convert the input to AbstractFloat or Union{Missing,<:Number}"))
_hfilter_padding(h::Int, p::Int, x::AbstractVector{T}) where {T} =
    _hfilter_padding(h, p, eltype(x))

"""
    apply(hfilter::HamiltonFilter, data::Vector{<:Union{Missing,<:Real}})

Applies the Hamilton filter to a univariate time series. Returns a tuple
containing the estimated trend and cyclical components. Due to filtering,
the first `(p-1) + h` observations are lost. Padding depends on the input type. 

- If the input type is `<:Real`, `NaN`s will be used for padding. 
- If the input type is `Union{Missing, <:Real}`, `missing` will be used for the 
  padding.

Missing values, ecoded as `missing`, `NaN`, or `Inf`, are handled by limiting the 
filter regression to only those period for which all data is available. Trend 
and Cycle components can then be computed for all periods for which all 
regressors are avaiable. This implies that sometimes a trend exponent can exist 
even if we cannot obtain the cyclical component, since the cyclical component 
also requires the observation to be non-missing -- the trend only requires all 
regressors to be non-missing. 

Missing values are again filled with `NaN`, `missing`, or `Inf`, depending on 
how they were initially encoded. 

# Arguments

- `hfilter::HamiltonFilter`: A `HamiltonFilter` instance.
- `data::Vector{Union{Missing,<:Real}}`: A vector of real-valued observations.

# Returns

- `(trend::Vector, cycle::Vector)`: A pair of vectors of the same length
  as `data`.
"""
function apply(hfilter::HamiltonFilter, data::AbstractVector{T}) where {T<:Union{Missing,<:Real}}
    padding = _hfilter_padding(hfilter.h, hfilter.p, data)
    trend = similar(data)
    trend[1:hfilter.h+hfilter.p-1] .= padding
    cycle = similar(data)
    cycle[1:hfilter.h+hfilter.p-1] .= padding

    trend_, cycle_ = _hamilton_filter(data, hfilter.h, hfilter.p)
    trend[(hfilter.p+hfilter.h):end] .= trend_
    cycle[(hfilter.p+hfilter.h):end] .= cycle_
    return trend, cycle
end

"""
    apply(hfilter::HamiltonFilter, data::Union{AbstractMatrix,DataFrame})

Applies the Hamilton filter column-wise to a multivariate dataset. Returns
the estimated trend and cyclical components for each column. Due to
filtering, the first `(p-1) + h` observations in each column are lost. Padding 
depends on the type of each column. 

- If the column type is `<:Real`, `NaN`s will be used for padding. 
- If the column type is `Union{Missing, <:Real}`, `missing` will be used for the 
  padding.

Missing values, ecoded as `missing`, `NaN`, or `Inf`, are handled by limiting the 
filter regression to only those period for which all data is available. Trend 
and Cycle components can then be computed for all periods for which all 
regressors are avaiable. This implies that sometimes a trend exponent can exist 
even if we cannot obtain the cyclical component, since the cyclical component 
also requires the observation to be non-missing -- the trend only requires all 
regressors to be non-missing. 

Missing values are again filled with `NaN`, `missing`, or `Inf`, depending on 
how they were initially encoded. 

# Arguments
- `hfilter::HamiltonFilter`: A `HamiltonFilter` instance.
- `data::Union{Matrix{<:Real}, DataFrame}`: A matrix or DataFrame with
  real-valued columns.

# Returns
- `(trend, cycle)`: Two matrices or DataFrames of the same size as `data`.
"""
function apply(
    hfilter::HamiltonFilter,
    data::Union{AbstractMatrix,DataFrame}
)

    trend = similar(data)
    cycle = similar(data)

    for i in axes(data, 2)
        col = data[:, i]
        eltype(col) <: Union{Missing,<:Real} || throw(ArgumentError("Column is not <:Union{Missing,<:Real}"))
        trend[:, i], cycle[:, i] = apply(hfilter, col)
    end
    return trend, cycle
end

end
