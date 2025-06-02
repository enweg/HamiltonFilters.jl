using HamiltonFilters
using DataFrames
using CSV
using Test

@testset "Implementation tests" begin
    hfilter = HamiltonFilter(8, 4)
    v = randn(1000)
    trend, cycle = apply(hfilter, v)
    X = randn(1000, 10)
    trend, cycle = apply(hfilter, X)
    df = DataFrame(X, :auto)
    trend, cycle = apply(hfilter, df)
end

@testset "Padding tests" begin
    x = randn(2)
    padding = HamiltonFilters._hfilter_padding(8, 4, x)
    @test all(isnan.(padding))
    @test length(padding) == 11
    x = [randn(2)..., missing]
    padding = HamiltonFilters._hfilter_padding(8, 4, x)
    @test all(ismissing.(padding))
    @test length(padding) == 11
    @test_throws ArgumentError HamiltonFilters._hfilter_padding(2, 2, 1:10)
end

@testset "Comparison to Matlab" begin
    log_gdp = DataFrame(CSV.File("./logGDPC1.csv"))
    matlab_hfilter = DataFrame(CSV.File("./matlab_hfilter.csv"))

    hfilter = HamiltonFilter(8, 4)
    trend, cycle = apply(hfilter, log_gdp)

    @test sum(isnan.(trend.GDPC1)) == sum(isnan.(matlab_hfilter.Trend))
    @test sum(isnan.(trend.GDPC1)) == 11
    @test isapprox(trend.GDPC1[12:end], matlab_hfilter.Trend[12:end]; atol=1e-6)
    @test isapprox(cycle.GDPC1[12:end], matlab_hfilter.Cycle[12:end]; atol=1e-6)
end

# TODO: document + publish
@testset "Handling missing values" begin
    # a data point should be missing whenever 
    # - the original data point is missing 
    # - whenever one of the data points needed to compute the trend is 
    #   missing
    h = 8
    p = 4
    lags = h:1:(h+p-1)
    hfilter = HamiltonFilter(8, 4)

    data = Float64.(1:10_000)
    idx_missing = unique(rand(1:length(data), 100))

    data_nan = copy(data)
    data_nan[idx_missing] .= NaN
    trend, cycle = apply(hfilter, data_nan)
    # are all original missing points missing
    # this only applies to the cycle because trend can maybe still be computed
    @test all(isnan.(cycle[idx_missing]))
    # whenever one of lags is missing, point needs to be missing
    # applies to both trend and cycle
    idx_should_be_missing = unique(reduce(vcat, map(x -> x .+ lags, idx_missing)))
    @test all(isnan.(cycle[idx_should_be_missing]))
    @test all(isnan.(trend[idx_should_be_missing]))
    # there should be no other missing values
    idx_should_be_nonmissing = setdiff(1:length(data), union(idx_missing, idx_should_be_missing))
    idx_should_be_nonmissing = setdiff(idx_should_be_nonmissing, 1:(h+p-1))
    @test !any(isnan.(cycle[idx_should_be_nonmissing]))
    @test !any(isnan.(trend[idx_should_be_nonmissing]))


    data_missing = Union{Missing,Float64}[data...]
    data_missing[idx_missing] .= missing
    trend, cycle = apply(hfilter, data_missing)
    # are all original missing points missing
    # this only applies to the cycle because trend can maybe still be computed
    @test all(ismissing.(cycle[idx_missing]))
    # whenever one of lags is missing, point needs to be missing
    # applies to both trend and cycle
    idx_should_be_missing = unique(reduce(vcat, map(x -> x .+ lags, idx_missing)))
    @test all(ismissing.(cycle[idx_should_be_missing]))
    @test all(ismissing.(trend[idx_should_be_missing]))
    # there should be no other missing values
    idx_should_be_nonmissing = setdiff(1:length(data), union(idx_missing, idx_should_be_missing))
    idx_should_be_nonmissing = setdiff(idx_should_be_nonmissing, 1:(h+p-1))
    @test !any(ismissing.(cycle[idx_should_be_nonmissing]))
    @test !any(ismissing.(trend[idx_should_be_nonmissing]))
end
