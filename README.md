> [!NOTE]
> This package may be merged into a larger project in the future.
> However, it will remain available as a stand-alone package for users
> who prefer minimal dependencies. The current API is considered stable.

# HamiltonFilters.jl

`HamiltonFilters.jl` is a lightweight implementation of the Hamilton
filter for time series analysis. It is not registered in the Julia
package registry, but can be installed directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/enweg/HamiltonFilters.jl")
```

To pin the package to a specific version:

```julia
Pkg.add(PackageSpec(url="https://github.com/enweg/HamiltonFilters.jl",
                    rev="v1.0.0"))
```

Once installed, load the package with:

```julia
using HamiltonFilters
```

## What does the Hamilton filter do?

The Hamilton filter estimates trend and cyclical components by running
the following regression:

$$
y_{t+h} = \beta_0 + \beta_1 y_t + \beta_2 y_{t-1} + \dots + \beta_p y_{t-p+1} + \nu_{t+h}
$$

You must choose two parameters:
- `h`: forecast horizon
- `p`: number of most recent values at time `t` (including `y_t`)

Hamilton (2018) recommends:

| Frequency | h | p |
|-----------|---|---|
| Yearly    | 2 | ? |
| Quarterly | 8 | 4 |
| Monthly   | 24| ? |

In general, he recommends that both `h` and `p` are integer multiples
of the number of observations in a year if the original data is 
seasonal.

If the series is integrated of order `d` or stationary around a
d-th-order polynomial, choose `p >= d` to obtain a stationary cycle.

The cyclical component is defined as the regression residuals:

$$
\hat\nu_{t+h} = y_{t+h} - \hat y_{t+h}
$$

The trend is the difference between the observed data and the cycle.

Only observations starting from index `p + h` can be used for filtering.

## Using the Hamilton filter

Load the package:

```julia
using HamiltonFilters
```

Construct a filter instance:

```julia
h = 8
p = 4
hfilter = HamiltonFilter(h, p)
```

Apply the filter to a time series:

```julia
trend, cycle = filter(hfilter, data)
```

The `filter` function always returns a tuple of the form `(trend, cycle)`.

- If `data` is a `Vector{<:Real}`, then `trend` and `cycle` are vectors
  of the same length as `data`. The first `(p-1) + h` values are filled
  with `NaN`.

- If `data` is a `Matrix{<:Real}`, then `trend` and `cycle` are matrices
  of the same size as `data`. The filter is applied to each column
  independently, and the first `(p-1) + h` rows are filled with `NaN`.

- If `data` is a `DataFrame`, then `trend` and `cycle` are DataFrames of
  the same shape and with the same column names. The filter is applied
  column-wise, and the first `(p-1) + h` rows are filled with `NaN`.

## Has the implementation been tested?

Yes. The implementation has been compared to the `hfilter` function in
Matlab using real GDP data. The `test` folder contains:

- `logGDPC1.csv`: log real GDP from FRED
- `matlab_hfilter.csv`: Matlab output for comparison

The filter output matches the benchmark.
