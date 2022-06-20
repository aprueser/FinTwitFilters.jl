module FinTwitFilters
    ## Base constants
    tradingWeeksInYear = 52::Int64
    tradingDaysInYear  = 253::Int64
    tradingDaysInQtr   = convert(Int64, round(tradingDaysInYear/4, digits = 0))::Int64
    tradingDaysInMonth = convert(Int64, round(tradingDaysInYear/12, digits = 0))::Int64
    tradingDaysInWeek  = 5::Int64

    ## Stock Filters
    minPriceFilter     = 10::Int64
    minMarketCapFilter = 300000000::Int64
    minVolFilter       = 400000::Int64
    minDollarVolFilter = 20000000::Int64

    ## ETFs to track


    ## External Libraries
    using Actors, .Threads, Dates, Printf, ProgressBars, Parameters, Temporal, DataFrames, DataFramesMeta, Indicators, MarketLists, TDAmeritradeAPI

    import Actors: spawn

    ## Exported Functions
    export getExchangeUniverse, fetchSymbolData,
           Stock, getLastClose, getFirstCandleDate, getLastCandleDate, getLastDollarVolume, get52WkLow, get52WkHigh,
           addSMA!, addEMA!, addROC!, addGaps!, addCandleType!, addWickPlayFlag!,
           toWeeklyOHLC, toMonthlyOHLC, toQuarterlyOHLC, toYearlyOHLC

    ## Include Package implementation
    include("Stock.jl")
    include("FetchData.jl")

    ## Package Stock List
    stockList = Dict{String, FinTwitFilters.Stock}()
    loadingStatus = Dict{String, Int64}()

end
