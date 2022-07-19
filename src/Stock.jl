@with_kw mutable struct Stock
    ## Status:
    ##  INIT           - Created from Exchange Member Lookup
    ##  OHLC_RAW       - OHLCV Data has been fetched from API, but is still RAW JSON
    ##  OHLC_PARSED    - OHLCV Data has been parsed into a Temporal.TS timeseries
    ##  OHLC_COLLAPSED - OHLCV Data has been collapsed into weekly, monthly, quarterly, and yearly OHLCV timeseries
    ##  OHLC_AUGMENTED - OHLCV Data has been augmented with FinTwit favorite Indicators
    ##  OHLC_FAILED       - API Lookup for OHLCV Data failed  
    ##  OHLC_PARSE_FAILED - JSON Parse for OHLCV Data failed
    status::String = "INIT"

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

    ## Symbol Fundamental Data
    fundamentals::Union{DataFrames.DataFrame, Dict{Symbol, Union{Int16, String, Vector{UInt8}}},  Missing} = missing

    ## Symbol OHLC Data
    ohlc::Union{Temporal.TS, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing, DataFrame} = missing

    wkohlc::Union{Temporal.TS, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing}  = missing
    mthohlc::Union{Temporal.TS, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing} = missing
    qtrohlc::Union{Temporal.TS, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing} = missing
    yrohlc::Union{Temporal.TS, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing}  = missing

    ## Symbol Options Chain
    options::Union{DataFrames.DataFrame, Dict{Symbol, Union{Int16, String, Vector{UInt8}}}, Missing} = missing
end

## Convert to weekly OHLC data
function toWeeklyOHLC(ohlc::Union{Temporal.TS, Missing})
    wk = hcat(collapse(ohlc[:Open], eow, fun=first),
        collapse(ohlc[:High], eow, fun=maximum), 
        collapse(ohlc[:Low], eow, fun=minimum), 
        collapse(ohlc[:Close], eow, fun=last),
        collapse(ohlc[:Volume], eow, fun=sum));

    return wk;
end

## Convert to monthly OHLC data
function toMonthlyOHLC(ohlc::Union{Temporal.TS, Missing})
    mon = hcat(collapse(ohlc[:Open], eom, fun=first),
        collapse(ohlc[:High], eom, fun=maximum), 
        collapse(ohlc[:Low], eom, fun=minimum), 
        collapse(ohlc[:Close], eom, fun=last),
        collapse(ohlc[:Volume], eom, fun=sum));

    return mon;
end

## Convert to quarterly OHLC data
function toQuarterlyOHLC(ohlc::Union{Temporal.TS, Missing})
    qtr = hcat(collapse(ohlc[:Open], eoq, fun=first),
        collapse(ohlc[:High], eoq, fun=maximum), 
        collapse(ohlc[:Low], eoq, fun=minimum), 
        collapse(ohlc[:Close], eoq, fun=last),
        collapse(ohlc[:Volume], eoq, fun=sum));

    return qtr;
end

## Convert to yearly OHLC data
function toYearlyOHLC(ohlc::Union{Temporal.TS, Missing})
    yr = hcat(collapse(ohlc[:Open], eoy, fun=first),
        collapse(ohlc[:High], eoy, fun=maximum), 
        collapse(ohlc[:Low], eoy, fun=minimum), 
        collapse(ohlc[:Close], eoy, fun=last),
        collapse(ohlc[:Volume], eoy, fun=sum));

    return yr;
end

## Add fields to the OHLC data that allow easier computation of common FinTwit Technical Analysis
function addSMA!(ohlc::Union{Temporal.TS, Missing}, field::Symbol, len::Int64, colName::Symbol)
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) > len
        ohlc[colName] = sma(ohlc[field].values[:,1], n = (size(ohlc)[1] > len ? len : size(ohlc)[1] - 1))

        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) <= len
	ohlc[colName] = fill(NaN, size(ohlc, 1))

        return;
    end
end

function addEMA!(ohlc::Union{Temporal.TS, Missing}, field::Symbol, len::Int64, colName::Symbol)
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) > len 
        ohlc[colName] = ema(ohlc[field].values[:,1], n = (size(ohlc)[1] > len ? len : size(ohlc)[1] - 1))

        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) <= len
	ohlc[colName] = fill(NaN, size(ohlc, 1))

        return;
    end
end

function addROC!(ohlc::Union{Temporal.TS, Missing}, field::Symbol, len::Int64, colName::Symbol)
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) > len
        ohlc[colName] = roc(ohlc[field].values[:,1], n = (size(ohlc)[1] > len ? len : size(ohlc)[1] - 1))

        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) <= len
	ohlc[colName] = fill(NaN, size(ohlc, 1))

        return;
    end
end

function addCandleType!(ohlc::Union{Temporal.TS, Missing})
    lagTS = Temporal.lag

    ## Add candleType
    ## 1 = Inside Day, 2 = Trending Day, 3, Outside Day
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) > 1
        ohlc[:candleType] = map((i, o) -> i == false && o == false ? 2 : i == true ? 1 : 3, 
            ohlc[:High].values[:,1] .< lagTS(ohlc[:High], 1, pad=true, padval=NaN).values[:,1] .&& ohlc[:Low].values[:,1] .> lagTS(ohlc[:Low], 1, pad=true, padval=NaN).values[:,1], 
            ohlc[:High].values[:,1] .> lagTS(ohlc[:High], 1, pad=true, padval=NaN).values[:,1] .&& ohlc[:Low].values[:,1] .< lagTS(ohlc[:Low], 1, pad=true, padval=NaN).values[:,1])
    
        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) <= 1
	ohlc[:candleType] = fill(NaN, size(ohlc, 1))

	return;
    end
end

function addWickPlayFlag!(ohlc::Union{Temporal.TS, Missing})
    lagTS = Temporal.lag

    ## Top Wick after an Up Day
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS && size(ohlc, 1) > 1
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
    elseif ohlc isa Temporal.TS && size(ohlc, 1) <= 1
	ohlc[:inTopWick] = fill(0.0, size(ohlc, 1)) 
	ohlc[:inBottomWick] = fill(0.0, size(ohlc, 1)) 
    end
end

function addPowerOfThree!(ohlc::Union{Temporal.TS, Missing})
    ## Add Power of 3 Flag
    if ismissing(ohlc)
        return;
    elseif ohlc isa Temporal.TS
        ohlc[:SMA10EMA21SMA50PctDiff] = 100 .- ((minimum(ohlc[[:CloseSMA10, :CloseEMA21, :CloseSMA50]].values, dims=2) ./ maximum(ohlc[[:CloseSMA10, :CloseEMA21, :CloseSMA50]].values, dims=2)) .* 100.00)
    end
end

function addGaps!(ohlc::Union{Temporal.TS, Missing}, pctChangeInVol::Int64 = 200, gapSizePct::Int64 = 10)
    ## Add a flag to identify gap up, and gap down days
    if size(ohlc[:VolumePctChangeDay], 2) > 0 && size(ohlc[:ClosePctChangeDay], 2) > 0
    	ohlc[:gapUp]   = ohlc[[:VolumePctChangeDay]].values .> pctChangeInVol .&& ohlc[[:ClosePctChangeDay]].values .> gapSizePct
    	ohlc[:gapDown] = ohlc[[:VolumePctChangeDay]].values .> pctChangeInVol .&& ohlc[[:ClosePctChangeDay]].values .< (-1 * gapSizePct)
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
        if size(ohlc, 1) < tradingDaysInYear
            minimum(ohlc[[:Open, :Close, :High]])
        else
            minimum(ohlc[end - tradingDaysInYear:end, [:Open, :Close, :High]])
        end
    end
end
