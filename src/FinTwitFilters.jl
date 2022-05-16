module FinTwitFilters

    ## Exported Functions
    export Stock, getLastClose, getFirstCandleDate, getLastCandleDate, 
           getExchangeUniverse

    ## External Libraries
    using Dates, Parameters, Temporal, TimeSeries, DataFrames, DataFramesMeta, MarketLists

    ## Include Package implementation
    include("Stock.jl")
    include("ohlcFetch.jl")

end
