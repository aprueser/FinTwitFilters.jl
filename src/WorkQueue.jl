mutable struct WorkQueue
    capacity::Int
    tickers::Array{Any,1}
    prod::Array{Link,1}
    cons::Array{Link,1}
    count::Int

    WorkQueue(capacity::Int) = new(capacity, Any[], Link[], Link[], 0)
end

available(w::WorkQueue)    = 0 < length(w.tickers) < w.capacity
isfull(w::WorkQueue)       = length(w.tickers) ≥ w.capacity
Base.isempty(w::WorkQueue) = isempty(w.tickers)

@msg Put Full Done Ok Take Empty Notify

function (w::WorkQueue)(::Put, prod, ticker)
    if isfull(w)
        send(prod, Full(), ticker)
        push!(w.prod, prod)
    elseif w.count < w.capacity
        push!(w.tickers, ticker)
        w.count += 1
        w.count == w.capacity ?
            send(prod, Done()) :
            send(prod, Ok(), ticker)
        !isempty(w.cons) && send(popfirst!(w.cons), Notify())
    else
        send(prod, Done())
    end
end

function (w::WorkQueue)(::Take, cons)
    if isempty(w)
        send(cons, Empty())
        push!(w.cons, cons)
    else
        send(cons, popfirst!(w.tickers))
        !isempty(w.prod) && send(popfirst!(w.prod), Notify())
    end
end

struct Prod
    name::String
    custkey::String
    queue::Link
end

struct Cons
    name::String
    queue::Link
end

## Start a logging Actor
prn = spawn(s->print(@sprintf("%s\n", s)))

function APIFetcher_Start(p::Prod, ticker)
    become(ohlc_fetcher, p)
    send(self(), ticker)
    send(prn, "Producer $(p.name) started.")
end

function JSONParser_Start(c::Cons)
    become(ohlc_parser, c)
    send(c.queue, Take(), self())
    send(prn, "Consumer $(c.name) started.")
end

function ohlc_fetcher(p::Prod, ticker)
    if ismissing(ticker.ohlc)
        apiKey = TDAmeritradeAPI.apiKeys(p.custKey, "", now(), "", now(), now() - Minute(30), "unauthorized");
        ticker.ohlc = TDAmeritradeAPI.api_getPriceHistoryRaw(ticker.symbol, apiKey, periodType = "year", numPeriods = 10, frequencyType = "daily", frequency = 1);
    end
    send(p.queue, Put(), self(), ticker)
end

function ohlc_fetcher(p::Prod, ::Ok, ticker)
    send(prn, "Producer $(p.name) delivered ticker $ticker")
    senD(self(), ticker)
end

function ohlc_fetcher(p::Prod, ::Full, ticker)
    send(prn, "Producer $(p.name) stalled with ticker $ticker")
    become(stalled, p, ticker)
end

function ohlc_fetcher(p::Prod, ::Done)
    send(prn, "Producer $(p.name) done")
    stop()
end

function stalled(p::Prod, ticker, ::Notify)
    send(p.queue, Put(), self(), ticker)
    become(producing, p)
end



function ohlc_parser(c::Cons, ticker)
    become(consuming, c)
    send(self(), c)
    send(prn, "consumer $(c.name) got ticker $ticker")
end

function ohlc_parser(c::Cons, ::Empty)
    become(waiting, c)
    send(prn, "consumer $(c.name) found queue empty")
end

function consuming(c, ticker)
    ticker.ohlc = TDAmeritradeAPI.parseRawPriceHistoryToTemporalTS(ticker.ohlc, ticker.symbol);
    become(ohlc_parser, c)
    send(c.queue, Take(), self())
end

function waiting(c::Cons, ::Notify)
    become(ohlc_parser, c)
    send(c.queue, Take(), self())
end

