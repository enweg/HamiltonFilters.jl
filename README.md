<p align="center">
  <img src="assets/logo.png"
       alt="Logo of HamiltonFilters.jl"
       width="450">
</p>


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
                    rev="v2.0.0"))
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
trend, cycle = apply(hfilter, data)
```

The `filter` function always returns a tuple of the form `(trend, cycle)`.

- If `data` is a `Vector{<:Real}`, then `trend` and `cycle` are vectors
  of the same length as `data`. The first `(p-1) + h` values are filled
  with `NaN`.
- If `data` is a `Vector{Union{Missing,<:Real}}`, then `trend` and `cycle` 
  are vectors of the same length as `data`. The first `(p-1) + h` values are 
  filled with `missing`.

- If `data` is a `Matrix{<:Real}`, then `trend` and `cycle` are matrices
  of the same size as `data`. The filter is applied to each column
  independently, and the first `(p-1) + h` rows are filled with `NaN`.
- If `data` is a `Matrix{Union{Missing,<:Real}}`, then `trend` and `cycle` 
  are matrices of the same size as `data`. The filter is applied to each column
  independently, and the first `(p-1) + h` rows are filled with `missing`.

- If `data` is a `DataFrame`, then `trend` and `cycle` are DataFrames of
  the same shape and with the same column names. The filter is applied
  column-wise, and the first `(p-1) + h` rows are either filled with `NaN` or 
  missing, depending on the type of the column.

## Has the implementation been tested?

Yes. The implementation has been compared to the `hfilter` function in
Matlab using real GDP data. The `test` folder contains:

- `logGDPC1.csv`: log real GDP from FRED
- `matlab_hfilter.csv`: Matlab output for comparison

The filter output matches the benchmark.

## Are missing values allowed? 

Missing values are handled internally using the following procedure: 

1. We create both the regressor matrix and the outcome vector for the regression 
   that needs to be estimated. 
2. We then find all the rows in the regressor matrix that contain `NaN`, `Inf`, 
   or `missing`. We do the same for the outcome vector. The intersection of the 
   two are all the observations that we cannot use for the estimation of the 
   regression. 
3. The regression is estimated using all those columns that do not contain `NaN`
   `Inf` or `missing` in either the regressor matrix or the outcome vector. 
4. The trend is obtained via the fitted values. Thus, the trend can be obtained 
   for all observations for which none of the regressors is `NaN`, `Inf`, or 
   `missing`. 
5. The cycle is obtained as the difference between the observation and the trend. 
   Thus, computing the cycle requires that both the regressors and the observation 
   is not `NaN`, `Inf`, or `missing`. 
6. Depending on the missing type (`NaN`, `Inf`, `missing`), values that cannot 
   be computed are replaced by `NaN`, `Inf`, `missing`. For this step we rely 
   on Julia's internal handling of mathematical computations using `NaN`, `Inf`, 
   and `missing`. 

The precendence of missingness is `missing` > `NaN` > `Inf`. Thus: 
- If values needed for the computation of trend or cycle only contain one of 
  `missing`, `NaN`, or `Inf`, then missing values are filled with that value. 
- If values needed for the computation of trend or cycle contain more than 
  one of `missing`, `NaN`, or `Inf`, then missing values are filled using the 
  highest precedence value. E.g. `missing` is used if both `missing` and `NaN` 
  are present. 
