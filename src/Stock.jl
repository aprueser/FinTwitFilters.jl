@with_kw mutable struct Stock
    ## Symbol Descriptors
    ticker::String     
    company::String 
    exchange::String   
    marketCap::Float64    = 0.0
    marketCapName::String = marketCap > 200000000000 ? "Mega"  :
                            marketCap > 10000000000  ? "Large" :
                            marketCap > 2000000000   ? "Mid"   :
                            marketCap > 300000000    ? "Small" : "Micro"
    sector::String        = ""
    industry::String      = ""
    country::String       = ""

    ## Symbol OHLC Data
    fundamentals::Union{DataFrames.DataFrame, Missing}                                   = missing
    ohlc::Union{Temporal.TS, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing} = missing
    options::Union{DataFrames.DataFrame, Missing}                                        = missing
end

## Add fields to the OHLC data that allow easier computation of common FinTwit Technical Analysis
function addSMA!(ohlc::Union{Temporal.TS, Missing}, field::Symbol, len::Int64, colName::Symbol)
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS
        ohlc[colName] = sma(ohlc[field].values[:,1], n = (size(ohlc)[1] > len ? len : size(ohlc)[1] - 1))

        return;
    end
end

function addEMA!(ohlc::Union{Temporal.TS, Missing}, field::Symbol, len::Int64, colName::Symbol)
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS
        ohlc[colName] = ema(ohlc[field].values[:,1], n = (size(ohlc)[1] > len ? len : size(ohlc)[1] - 1))

        return;
    end
end

function addROC!(ohlc::Union{Temporal.TS, Missing}, field::Symbol, len::Int64, colName::Symbol)
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS
        ohlc[colName] = roc(ohlc[field].values[:,1], n = (size(ohlc)[1] > len ? len : size(ohlc)[1] - 1))

        return;
    end
end

function addCandleType!(ohlc::Union{Temporal.TS, Missing})
    lagTS = Temporal.lag

    ## Add candleType
    ## 1 = Inside Day, 2 = Trending Day, 3, Outside Day
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS
        ohlc[:candleType] = map((i, o) -> i == false && o == false ? 2 : i == true ? 1 : 3, 
            ohlc[:High].values[:,1] .< lagTS(ohlc[:High], 1, pad=true, padval=NaN).values[:,1] .&& ohlc[:Low].values[:,1] .> lagTS(ohlc[:Low], 1, pad=true, padval=NaN).values[:,1], 
            ohlc[:High].values[:,1] .> lagTS(ohlc[:High], 1, pad=true, padval=NaN).values[:,1] .&& ohlc[:Low].values[:,1] .< lagTS(ohlc[:Low], 1, pad=true, padval=NaN).values[:,1])
    
        return;
    end
end

function addWickPlayFlag!(ohlc::Union{Temporal.TS, Missing})
    lagTS = Temporal.lag

    ## Top Wick after an Up Day
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS
        ohlc[:inTopWick] = map(w -> w == true ? 1 : 0,
            (lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1] .> lagTS(ohlc[:Open], 1, pad=true, padval=NaN).values[:,1]) .&&  ## Last candle was green
            (lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1] .< lagTS(ohlc[:High], 1, pad=true, padval=NaN).values[:,1]) .&&  ## Last candle closed below high, leaving wick
            (ohlc[:Open].values[:,1] .> lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1]) .&&                                         ## Current Open above last close
            (ohlc[:Open].values[:,1] .< lagTS(ohlc[:High], 1, pad=true, padval=NaN).values[:,1]) .&&                                          ## Current Open below last high
            (ohlc[:Low].values[:,1] .> lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1])                                              ## Current Low above last close
        )

        ## Bottom Wick after a Down Day
        ohlc[:inBottomWick] = map(w -> w == true ? 1 : 0,
            (lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1] .< lagTS(ohlc[:Open], 1, pad=true, padval=NaN).values[:,1]) .&&  ## Last candle was red
            (lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1] .> lagTS(ohlc[:Low], 1, pad=true, padval=NaN).values[:,1]) .&&   ## Last candle closed above low, leaving wick
            (ohlc[:Open].values[:,1] .< lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1]) .&&                                         ## Current Open below last close
            (ohlc[:Open].values[:,1] .> lagTS(ohlc[:Low], 1, pad=true, padval=NaN).values[:,1]) .&&                                           ## Current Open above last low
            (ohlc[:High].values[:,1] .< lagTS(ohlc[:Close], 1, pad=true, padval=NaN).values[:,1])                                             ## Current High below last close
        )
    end
end

## Get get values from the OHLC data
function getLastClose(ohlc::Union{Temporal.TS, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc[end, :Close].values[1,1]
    end
end

function getFirstCandleDate(ohlc::Union{Temporal.TS, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc.index[1]
    end
end

function getLastCandleDate(ohlc::Union{Temporal.TS, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc.index[end]
    end
end

function getLastDollarVolume(ohlc::Union{Temporal.TS, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc[end, :Close].values[1,1] * ohlc[end, :Volume].values[1,1]
    end
end

function get52WkHigh(ohlc::Union{Temporal.TS, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        ## If there is not a full year's worth of candles, get the max for the data available
        if size(ohlc)[1] < tradingDaysInYear
            maximum(ohlc[[:Open, :Close, :High]])
        else
            maximum(ohlc[end - tradingDaysInYear:end, [:Open, :Close, :High]])
        end
    end
end

function get52WkLow(ohlc::Union{Temporal.TS, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        ## If there is not a full year's worth of candles, get the max for the data available
        if size(ohlc)[1] < tradingDaysInYear
            minimum(ohlc[[:Open, :Close, :High]])
        else
            minimum(ohlc[end - tradingDaysInYear:end, [:Open, :Close, :High]])
        end
    end
end