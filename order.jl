"""
Check an order's status.
Either orderId or origClientOrderId must be sent.
"""
function query_order(user, symbol; orderId=0, clientOrderId="")
    if orderId != 0
        query = "$(query_head())&symbol=$symbol&orderId=$orderId"
    elseif clientOrderId != ""
        query = "$(query_head())&symbol=$symbol&origClientOrderId=$clientOrderId"
    end

    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/order?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end


"""
Cancel an order from user.
"""
function cancel_order(user, order)
    query = "$(query_head())&symbol=$(order["symbol"])&origClientOrderId=$(order["clientOrderId"])"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_ORDER_URL?$query&signature=$signature"
    response = HTTP.request("DELETE", body, user.headers)
    response_to_json(response.body)
end

"""
Cancel an order from user.
"""
function cancel_order(user, symbol; orderId=0, clientOrderId="")
    if orderId != 0
        query = "$(query_head())&symbol=$symbol&orderId=$orderId"
    elseif clientOrderId != ""
        query = "$(query_head())&symbol=$symbol&origClientOrderId=$clientOrderId"
    end

    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_ORDER_URL?$query&signature=$signature"
    response = HTTP.request("DELETE", body, user.headers)
    response_to_json(response.body)
end


"""
Execute an order to the account.
"""
function execute_order(order::Dict, user::User)
    order_params = order_dict_to_params(order)
    query = "$(query_head())&$order_params"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_ORDER_URL?$query&signature=$signature"
    response = HTTP.request("POST", body, user.headers)
    response_to_json(response.body)
end

"""
Cancel All Open Orders (TRADE)
"""
function cancel_all_open_orders(user, symbol)
    query = "$(query_head())&symbol=$symbol"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/allOpenOrders?$query&signature=$signature"
    response = HTTP.request("DELETE", body, user.headers)
    response_to_json(response.body)
end


"""
Create an order dict to be executed later.
"""
function create_order_dict(symbol::String, type::String, side::String;
    quantity::Float64=0.0, price::Float64=0.0, stopPrice::Float64=0.0,
    timeInForce::String="GTC", newClientOrderId::String="", newOrderRespType::String="RESULT",
    workingType::String="CONTRACT_PRICE", priceProtect::String="FALSE", positionSide::String="", reduceOnly::String="")

    if quantity <= 0.0
        error("Quantity cannot be <=0.")
    end

    # println("$side $symbol $quantity qty @ $price price.")

    order = Dict{String,Any}(
        "symbol" => symbol,
        "type" => type,
        "side" => side,
        "newOrderRespType" => newOrderRespType
    )

    if newClientOrderId != ""
        order["newClientOrderId"] = newClientOrderId
    end

    if positionSide != ""
        order["positionSide"] = positionSide
    end

    if reduceOnly != ""
        order["reduceOnly"] = reduceOnly
    end


    if type in ["LIMIT", "STOP", "TAKE_PROFIT"]

        if price <= 0.0
            error("Price should be no smaller than 0.")
        end
        order["price"] = price
        order["timeInForce"] = timeInForce
    end

    if type in ["LIMIT"]
        if price * quantity < 5.0
            error("Order's notional must be no smaller than 5.0 (unless you choose reduce only)")
        end
        order["quantity"] = quantity
    end

    if type in ["MARKET", "STOP", "TAKE_PROFIT", "STOP_MARKET", "TAKE_PROFIT_MARKET"]
        order["quantity"] = quantity
    end

    if type in ["TRAILING_STOP_MARKET"]
        order["callbackRate"] = callbackRate
    end

    # trigger price 
    if type in ["STOP", "TAKE_PROFIT", "STOP_MARKET", "TAKE_PROFIT_MARKET"]
        if stopPrice <= 0.0
            error("Stop price should be no smaller than 0.")
        end
        order["stopPrice"] = stopPrice
        order["workingType"] = workingType
        order["priceProtect"] = priceProtect
    end

    order
end

"""
Get open orders.
"""
function get_open_orders(user)
    query = query_head()
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/openOrders?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end

"""
Get open orders.
"""
function get_open_orders(user, symbol)
    query = "$(query_head())&symbol=$symbol"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/openOrders?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end


function get_presions(symbol)
    symbol_info = filter(x -> x["symbol"] == symbol, get_Binance_info()["symbols"])[1]
    symbol_info["pricePrecision"], symbol_info["quantityPrecision"]
end

function get_current_position(user, symbol)
    position = get_position(user, symbol)
    result = filter(x -> (string2float(x["isolatedMargin"]) > 0.0), position)
    # isempty(result) ? result : result[1]
end

# function _has_open_order(user, symbol)
#     try
#         query_order(user, symbol, clientOrderId="open")["status"] == "NEW"
#     catch
#         false
#     end
# end

function get_order_price(user, symbol, clientOrderId)
    try
        order = query_order(user, symbol, clientOrderId=clientOrderId)
        if order["status"] == "NEW"
            price = clientOrderId == "stop" ? order["stopPrice"] : order["price"]
            string2float(price)
        else
            0.0
        end
    catch
        0.0
    end
end

create_open_order_dict(symbol, side, quantity, price, positionSide) = create_order_dict(symbol, "LIMIT", side; quantity=quantity, price=price, newClientOrderId="open", positionSide=positionSide)
create_stop_order_dict(symbol, side, quantity, stopPrice, positionSide) = create_order_dict(symbol, "STOP_MARKET", side; quantity=quantity, stopPrice=stopPrice, newClientOrderId="stop", positionSide=positionSide)
create_profit_order_dict(symbol, side, quantity, price, positionSide) = create_order_dict(symbol, "TAKE_PROFIT", side; quantity=quantity, stopPrice=price, price=price, newClientOrderId="profit", positionSide=positionSide)


function cancel_no_use_order(user, symbol, has_position, has_open_order, has_stop_order, has_profit_order)
    if (!has_position) & (!has_open_order) & (has_stop_order || has_profit_order)
        cancel_all_open_orders(user, symbol)
    end
    return
end

cancel_open_order(user, symbol) = cancel_order(user, symbol; clientOrderId="open")
cancel_stop_order(user, symbol) = cancel_order(user, symbol; clientOrderId="stop")
cancel_profit_order(user, symbol) = cancel_order(user, symbol; clientOrderId="profit")
