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


"""
Get account information.
"""
function get_account_info(user)
    query = query_head()
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v2/account?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)

    if response.status != 200
        println(response)
        return response.status
    end

    response_to_json(response.body)
end


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


# Get current position information.
function get_position(user::User, symbol)
    query = "$(query_head())&symbol=$symbol"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v2/positionRisk?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end

function get_position(user::User)
    query = "$(query_head())"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v2/positionRisk?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end

"""
Get Binance information.
"""
get_Binance_info() = request_get(BINANCE_FUTURE_EXCHANGEINFO_URL)

function get_position(account_info::Dict, symbol)
    filter(x -> x["symbol"] == symbol, account_info["positions"])
end

"""
Get balances.
"""
function get_balances(user; balance_filter=x -> parse(Float64, x["walletBalance"]) > 0.0)
    account = get_account_info(user)
    balances = filter(balance_filter, account["assets"])
end

"""
Get balance.
"""
function get_balance(user, symbol)
    account = get_account_info(user)
    balance_filter = x -> x["asset"] == symbol
    balance = filter(balance_filter, account["assets"])[1]
    walletBalance, marginBalance, initialMargin, unrealizedProfit = string2float.([balance["walletBalance"], balance["marginBalance"], balance["initialMargin"], balance["unrealizedProfit"]])
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

function get_valid_coin_pairs()
    exchange_info = get_Binance_info()

    coin_pairs = []
    for s in exchange_info["symbols"]
        if (s["marginAsset"] == "USDT") & (s["contractType"] == "PERPETUAL") & (s["status"] == "TRADING")
            push!(coin_pairs, s["pair"])
        end
    end

    coin_pairs
end

function cal_price_diff(coin_pair)
    ohlcs = get_ohlc(coin_pair, "1m", 60)
    High = ohlcs[2]
    Low = ohlcs[3]

    price_diffs = @. High / Low - 1
    mean(price_diffs)
end

# get the best 20 coin pairs according to the price diffs
function get_best_trading_pairs()
    coin_pairs = get_valid_coin_pairs()

    price_diffs = [cal_price_diff(coin_pair) for coin_pair in coin_pairs]
    new_inds = sortperm(price_diffs, rev=true)
    coin_pairs[new_inds][1:20]
end