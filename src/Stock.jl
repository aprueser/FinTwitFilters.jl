@with_kw mutable struct Stock
    ## Symbol Descriptors
    ticker::String     
    company::String    
    marketCap::Float64    = 0.0
    marketCapName::String = marketCap > 200000000000 ? "Mega"  :
                            marketCap > 10000000000  ? "Large" :
                            marketCap > 2000000000   ? "Mid"   :
                            marketCap > 300000000    ? "Small" : "Micro"
    sector::String        = ""
    industry::String      = ""
    country::String       = ""

    ## Symbol OHLC Data
    fundamentals::Union{DataFrames.DataFrame, Missing}                            = missing
    ohlc::Union{Temporal.TS, TimeSeries.TimeArray, DataFrames.DataFrame, Missing} = missing
    options::Union{DataFrames.DataFrame, Missing}                                 = missing
end

function getLastClose(ohlc::Union{Temporal.TS, TimeSeries.TimeArray, DataFrames.DataFrame, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc[end, :Close].values[1,1]
    elseif ohlc isa  TimeSeries.TimeArray
        return values(ohlc[end, :Close])[1,1]
    elseif ohlc isa  DataFrames.DataFrame
        return last(ohlc).Close
    end
end

function getFirstCandleDate(ohlc::Union{Temporal.TS, TimeSeries.TimeArray, DataFrames.DataFrame, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc.index[1]
    elseif ohlc isa  TimeSeries.TimeArray
        return timestamp(ohlc)[1]
    elseif ohlc isa  DataFrames.DataFrame
        return first(ohlc).Datetime
    end
end

function getLastCandleDate(ohlc::Union{Temporal.TS, TimeSeries.TimeArray, DataFrames.DataFrame, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS
        return ohlc.index[end]
    elseif ohlc isa  TimeSeries.TimeArray
        return timestamp(ohlc)[end]
    elseif ohlc isa  DataFrames.DataFrame
        return last(ohlc).Datetime
    end
end

function get52WkHigh(ohlc::Union{Temporal.TS, TimeSeries.TimeArray, DataFrames.DataFrame, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS

    elseif ohlc isa  TimeSeries.TimeArray

    elseif ohlc isa  DataFrames.DataFrame
    
    end
end

function get52WkLow(ohlc::Union{Temporal.TS, TimeSeries.TimeArray, DataFrames.DataFrame, Missing})
    if ismissing(ohlc)
        return nothing;
    elseif ohlc isa Temporal.TS

    elseif ohlc isa  TimeSeries.TimeArray

    elseif ohlc isa  DataFrames.DataFrame
    
    end
end