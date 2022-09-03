"""
Get klines of symbol.
intervel can be "1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M";
limit <= 1500
"""
function get_klines(symbol; start_datetime=nothing, end_datetime=nothing, interval="1m", limit=1000)
    query = "?$(query_head())&symbol=$symbol&interval=$interval&limit=$limit"
    if start_datetime != nothing && end_datetime != nothing
        start_time = datetime_to_timestamp(start_datetime)
        end_time = datetime_to_timestamp(end_datetime)
        query = "$query&startTime=$start_time&endTime=$end_time"
    end
    url = "$BINANCE_FUTURE_KLINES_URL$query"
    request_get(url)
end

function get_klines_df(symbol; interval="1m", limit=1000)
    klines = get_klines(symbol, interval=interval, limit=limit)
    Open = parse.(Float64, [k[2] for k in klines])
    High = parse.(Float64, [k[3] for k in klines])
    Low = parse.(Float64, [k[4] for k in klines])
    Close = parse.(Float64, [k[5] for k in klines])
    DataFrame(Open=Open, High=High, Low=Low, Close=Close)
end


function get_ohlc(symbol, interval, limit)
    klines = get_klines(symbol, interval=interval, limit=limit)
    Open = parse.(Float64, [k[2] for k in klines])
    High = parse.(Float64, [k[3] for k in klines])
    Low = parse.(Float64, [k[4] for k in klines])
    Close = parse.(Float64, [k[5] for k in klines])
    colors = Close .>= Open

    linesegs = get_linesegs(Low, High, limit)
    last_price = Close[end]
    last_color = colors[end] ? :green : :red
    y_min = minimum(Low) * 0.997
    y_max = maximum(High) * 1.003

    Open, High, Low, Close, colors, linesegs, last_price, last_color, y_min, y_max
end