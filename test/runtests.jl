using HamiltonFilters
using DataFrames 
using CSV
using Test

@testset "HamiltonFilters.jl" begin
    # implementation tests
    hfilter = HamiltonFilter(8, 4)
    v = randn(1000)
    trend, cycle = filter(hfilter, v)
    X = randn(1000, 10)
    trend, cycle = filter(hfilter, X)
    df = DataFrame(X, :auto)
    trend, cycle = filter(hfilter, df)

    # Comparison to matlab
    log_gdp = DataFrame(CSV.File("./logGDPC1.csv"))
    matlab_hfilter = DataFrame(CSV.File("./matlab_hfilter.csv"))

    hfilter = HamiltonFilter(8, 4)
    trend, cycle = filter(hfilter, log_gdp)

    @test sum(isnan.(trend.GDPC1)) == sum(isnan.(matlab_hfilter.Trend))
    @test sum(isnan.(trend.GDPC1)) == 11
    @test isapprox(trend.GDPC1[12:end], matlab_hfilter.Trend[12:end]; atol=1e-6)
    @test isapprox(cycle.GDPC1[12:end], matlab_hfilter.Cycle[12:end]; atol=1e-6)

end
