using CairoMakie, Random, TimeSeries, Dates, GLMakie
using JSON, HTTP,  DataFrames

query_head() = "recvWindow=$recvWindow&timestamp=$(timestamp_now())"

"""
Convert HTTP response to JSON
"""
function response_to_json(response)
    JSON.parse(String(response))
end


"""
Get the request and convert to json.
"""
function request_get(url)
    response = HTTP.request("GET", url)
    response_to_json(response.body)
end

const BINANCE_FUTURE_BASE_URL = "https://fapi.binance.com"

const BINANCE_FUTURE_KLINES_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/klines"

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


const BINANCE_FUTURE_BASE_URL = "https://fapi.binance.com"
const BINANCE_FUTURE_ORDER_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/order"
const BINANCE_FUTURE_KLINES_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/klines"
const BINANCE_FUTURE_WS_URL = "wss://fstream.binance.com/ws"
const BINANCE_FUTURE_PING_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/ping"
const BINANCE_FUTURE_TIME_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/time"
const BINANCE_FUTURE_EXCHANGEINFO_URL = "https://www.binance.com/fapi/v1/exchangeInfo"
const BINANCE_FUTURE_AGGTRADES_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/aggTrades"

import HTTP, JSON, SHA, Printf, CSV
using DataFrames, DataStructures, ProgressMeter

recvWindow = 60000

"""
Get account information.
"""
function get_account_info(user)
    query = query_head()
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/account?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)

    if response.status != 200
        println(response)
        return response.status
    end

    response_to_json(response.body)
end

"""
USER stores the api_key and api_secret of an account.
"""
struct User
    key
    secret
    headers
    function User(api_key_file)
        api_dict = JSON.parsefile(api_key_file)
        key = api_dict["key"]
        secret = api_dict["secret"]
        headers = Dict("X-MBX-APIKEY" => key)
        new(key, secret, headers)
    end
end

function is_multi_assets_mode(user)
    query = query_head()
    # query = "timestamp=$(timestamp_now())"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/multiAssetsMargin?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)["multiAssetsMargin"]
end

function change_multi_assets_mode(user, mode)
    multiAssetsMargin0 = string(is_multi_assets_mode(user))
    multiAssetsMargin = (mode == "multi") ? "true" : "false"
    if multiAssetsMargin != multiAssetsMargin0
        query = "$(query_head())&multiAssetsMargin=$multiAssetsMargin"
        signature = do_sign(query, user)
        body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/multiAssetsMargin?$query&signature=$signature"
        response = HTTP.request("POST", body, user.headers)

        if response.status != 200
            println(response)
            return response.status
        end

        response_to_json(response.body)["msg"]
    end
end

# recvWindow = 60000

# """
# Get account information.
# """
# function get_account_info(user)
#     query = query_head()
#     signature = do_sign(query, user)
#     body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/account?$query&signature=$signature"
#     response = HTTP.request("GET", body, user.headers)

#     if response.status != 200
#         println(response)
#         return response.status
#     end

#     response_to_json(response.body)
# end


"""
Get balances.
"""
function get_balances(user; balance_filter=x -> parse(Float64, x["walletBalance"]) > 0.0)
    account = get_account_info(user)
    balances = filter(balance_filter, account["assets"])
end


import Dates

function datetime_to_string(datetime::Dates.DateTime)
    Dates.format(datetime, "yyyymmdd")
end


"""
Return current datetime in UTC format.
"""
datetime_now() = Dates.now(Dates.UTC)


"""
Return current date in UTC format.
"""
date_now() = Dates.Date(datetime_now())


"""
Convert a datetime to timestamp in the units of milliseconds.
"""
datetime_to_timestamp(datetime::Dates.DateTime) = Int64(Dates.datetime2unix(datetime) * 1000)


"""
Convert a datetime sting to timestamp.
datetime should in the format of "2021-03-01" or "2021-03-01T03:01:24"
"""
function datetime_to_timestamp(datetime::String)
    dt = Dates.DateTime(datetime)
    datetime_to_timestamp(dt)
end


"""
Convert a timestamp in the units of milliseconds to datetime format.
"""
timestamp_to_datetime(ts) = Dates.unix2datetime(ts/1000)


"""
Return the timestamp of now in the units of milliseconds.
"""
timestamp_now() = datetime_to_timestamp(datetime_now())


"""
Ping to the url.
"""
function ping(url)
    r = HTTP.request("GET", url)
    r.status
end


"""
Convert HTTP response to JSON
"""
function response_to_json(response)
    JSON.parse(String(response))
end


"""
Get the request and convert to json.
"""
function request_get(url)
    response = HTTP.request("GET", url)
    response_to_json(response.body)
end


"""
Convert an order_dict to an string parameter.
"""
function order_dict_to_params(order_dict::Dict)
    params = ""
    for (key, value) in order_dict
        params = "$params&$key=$value"
    end
    params[2:end]
end


"""
Hash the msg with key.
"""
function hmac(key::Vector{UInt8}, msg::Vector{UInt8}, hash, blocksize::Int=64)
    if length(key) > blocksize
        key = hash(key)
    end

    pad = blocksize - length(key)

    if pad > 0
        resize!(key, blocksize)
        key[end - pad + 1:end] = 0
    end

    o_key_pad = key .⊻ 0x5c
    i_key_pad = key .⊻ 0x36

    hash([o_key_pad; hash([i_key_pad; msg])])
end


"""
Sigh the query message with api_secret.x
"""
function do_sign(query, user)
    hash_value = hmac(Vector{UInt8}(user.secret), Vector{UInt8}(query), SHA.sha256)
    bytes2hex(hash_value)
end


"""
Make path if it doesn't exists.
"""
function mk_path(path)
    if !ispath(path)
        mkpath(path)
    end
end

"""
Remove file when it exists.
"""
function rm_file(file)
    if isfile(file)
        rm(file, recursive=true)
    end
end


function mk_save_path(symbol, cache)
    symbol_upper = uppercase(symbol)    
    save_path = "historical_data/$symbol_upper/$cache"
    mk_path(save_path)
    save_path
end


function json_to_dataframe(json_list)
    vcat(DataFrame.(json_list)...)
end


"""
Convert a bool value to 1 or 0.
"""
convert_bool_to_int8(bool) = bool==true ? Int8(1) : Int8(0)

string2float(str) = parse(Float64, str)

"""
Get balance.
"""
function get_balance(user, symbol)
    account = get_account_info(user)
    balance_filter = x -> x["asset"] == symbol
    balance = filter(balance_filter, account["assets"])[1]
    walletBalance, marginBalance, initialMargin, unrealizedProfit = string2float.([balance["walletBalance"], balance["marginBalance"], balance["initialMargin"], balance["unrealizedProfit"]])
end


import Indicators
const ID = Indicators


"""
Averaged commodity channel index
"""
function acci(close::Array{Float64}; n1::Int64=30, n2::Int64=10, c::T=0.015, ma::Function=ID.ema, args...)::Array{Float64} where {T<:Real}
    tp = close
    dev = ID.runmad(tp, n=n1, cumulative=false, fun=ID.mean)
    avg = ma(tp, n=n1; args...)
    _cci = (tp - avg) ./ (c * dev)
    ma(_cci, n=n2)
end


get_server_time() = request_get("$BINANCE_FUTURE_BASE_URL/fapi/v1/time")["serverTime"]

function is_hedge_mode(user)
    query = query_head()
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/positionSide/dual?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)["dualSidePosition"]
end

# change to "hedge" or "one-way" mode
function change_position_mode(user, mode)
    dualSidePosition0 = string(is_hedge_mode(user))
    dualSidePosition = (mode == "hedge") ? "true" : "false"
    if dualSidePosition != dualSidePosition0
        query = "$(query_head())&dualSidePosition=$dualSidePosition"
        signature = do_sign(query, user)
        body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/positionSide/dual?$query&signature=$signature"
        response = HTTP.request("POST", body, user.headers)

        if response.status != 200
            println(response)
            return response.status
        end

        response_to_json(response.body)["msg"]
    end
end

string2int(str) = parse(Int, str)

function change_leverage(user, symbol, leverage::Int)
    _, leverage0 = get_magrinType_leverage(user, symbol)
    if leverage != leverage0
        query = "$(query_head())&symbol=$symbol&leverage=$leverage"
        signature = do_sign(query, user)
        body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/leverage?$query&signature=$signature"
        response = HTTP.request("POST", body, user.headers)

        if response.status != 200
            println(response)
            return response.status
        end

        response_to_json(response.body)["leverage"]
    else
        leverage
    end
end

function get_magrinType_leverage(user, symbol)
    position = get_position(user, symbol)[1]
    uppercase(position["marginType"]), string2int(position["leverage"])
end

# change to "ISOLATED" or "CROSSED" mode
function change_margin_mode(user, symbol, marginType)
    marginType0, _ = get_magrinType_leverage(user, symbol)
    if marginType != marginType0
        query = "$(query_head())&symbol=$symbol&marginType=$marginType"
        signature = do_sign(query, user)
        body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/marginType?$query&signature=$signature"
        response = HTTP.request("POST", body, user.headers)

        if response.status != 200
            println(response)
            return response.status
        end

        response_to_json(response.body)["msg"]
    end
end