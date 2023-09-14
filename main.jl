include("init.jl")
using Indicators
const kline_limit = 100 # number of candlesticks (klines) to fetch and show

best_trading_pairs = get_best_trading_pairs()

coin_pair = Observable(best_trading_pairs[1])
time_interval = Observable("5m")
leverage = Observable(8)
stop_pct = Observable(2e-1)
profit_pct = Observable(5e-3);

# choose Long or Short mode
long_or_short = Observable("LONG")
long_or_short_chi = @lift $long_or_short == "LONG" ? "做多" : "做空"
order_side = @lift $long_or_short == "LONG" ? "BUY" : "SELL"
stop_order_side = @lift $long_or_short == "LONG" ? "SELL" : "BUY"
text_long_or_short = @lift $long_or_short_chi * " 模式"
text_long_or_short_color = @lift $long_or_short == "LONG" ? :green : :red

price_quantity_presions = @lift get_presions($coin_pair)
price_precision = @lift $price_quantity_presions[1]
quantity_precision = @lift $price_quantity_presions[2]

user = User("api_key.json");
account_info = get_account_info(user)
_margin_mode = @lift change_margin_mode(user, $coin_pair, "ISOLATED")
# 单资产模式
# change_multi_assets_mode(user, "single")
# change_position_mode(user, "hedge")
_leverage = @lift change_leverage(user, $coin_pair, $leverage)

base_coin = Observable("USDT")
balances = @lift get_balance(user, $base_coin)

wallet_balance = @lift round($balances[1], digits=3)
text_balance = @lift "资产 = " * string($wallet_balance) * "U"

position = @lift get_current_position(user, $coin_pair)
has_position = @lift !(isempty($position))
position_amount = @lift $has_position ? string2float($position[1]["positionAmt"]) : 0.0
text_position_amount = @lift "仓位 = " * string($position_amount)

position_price = @lift $has_position ? string2float($position[1]["entryPrice"]) : 0.0
text_position_price = @lift "开仓价 = " * string($position_price) * "U"


liq_price = @lift $has_position ? round(string2float($position[1]["liquidationPrice"]), digits=$price_precision) : 0.0
text_liq_price = @lift "爆仓价 = " * string($liq_price) * "U"

unPnL = @lift $has_position ? round(string2float($position[1]["unRealizedProfit"]), digits=3) : 0.0
text_unPnL = @lift "未实现盈亏 = " * string($unPnL) * "U"

open_price = @lift get_order_price(user, $coin_pair, "open")
stop_price = @lift get_order_price(user, $coin_pair, "stop")
profit_price = @lift get_order_price(user, $coin_pair, "profit")
text_open_price = @lift $long_or_short_chi * "@" * string($open_price)
text_stop_price = @lift "止损@" * string($stop_price)
text_profit_price = @lift "止盈@" * string($profit_price)

has_open_order = @lift $open_price != 0.0
has_stop_order = @lift $stop_price != 0.0
has_profit_order = @lift $profit_price != 0.0

_cancel_no_use_order = @lift cancel_no_use_order(user, $coin_pair, $has_position, $has_open_order, $has_stop_order, $has_profit_order)

ohlcs = @lift get_ohlc($coin_pair, $time_interval, kline_limit)

Open = @lift $ohlcs[1]
High = @lift $ohlcs[2]
Low = @lift $ohlcs[3]
Close = @lift $ohlcs[4]
colors = @lift $ohlcs[5]
linesegs = @lift $ohlcs[6]
last_price = @lift $ohlcs[7]
last_color = @lift $ohlcs[8]
y_min = @lift $ohlcs[9]
y_max = @lift $ohlcs[10];

ACCI = @lift acci($Close);

cmap = [:red, :green]

# plot setting
vratio = 4;
hratio = 4;

mouse_text_coor = kline_limit * 0.5
order_text_coor = kline_limit * 0.7 # the x-coordinate where to put the text

x_min = -3
x_max = kline_limit * 1.2

fig = Figure(font="sans", fontsize=20);

ax1 = Axis(fig[1:vratio, 1:hratio], title=coin_pair, yaxisposition=:right)
# deactivate_interaction!(ax1, :rectanglezoom)

# k线图
barplot!(ax1, 1:kline_limit, Open, fillto=Close, color=colors, strokewidth=0.5, strokecolor=colors, colormap=cmap)
linesegments!(ax1, linesegs, color=colors, colormap=cmap)
hlines!(ax1, last_price, color=last_color, linestyle=:dash, linewidth=1)

last_price_text = @lift string($last_price)
text!(ax1, mouse_text_coor, last_price, text=last_price_text, color=last_color)

# 改变做多或做空模式
on(events(ax1).keyboardbutton) do event
    if (!has_open_order[]) & (!has_position[])
        if ispressed(fig, Keyboard.s)
            long_or_short[] = "SHORT"
        elseif ispressed(fig, Keyboard.l)
            long_or_short[] = "LONG"
        end
    end
end

# 显示鼠标对应的价格
mouse_pos = lift(events(ax1).mouseposition) do mp
    mouseposition(ax1.scene)
end

mouse_pos_x = @lift $mouse_pos[1]
mouse_pos_y = @lift $mouse_pos[2]
mouse_open_price = @lift round(Float($mouse_pos[2]), digits=$price_precision)
mouse_stop_price = @lift round(cal_stop_price($long_or_short, $mouse_open_price, $stop_pct), digits=$price_precision)
mouse_profit_price = @lift round(cal_profit_price($long_or_short, $mouse_open_price, $profit_pct), digits=$price_precision)

# 开仓数量
quantity = @lift floor($wallet_balance * $leverage * 0.99 / $mouse_open_price, digits=$quantity_precision)

# 止赢、止损、开仓对应水平线
vlines!(ax1, mouse_pos_x, color=:red, linestyle=:dash, linewidth=1)
hlines!(ax1, mouse_open_price, linestyle=:dash, linewidth=1, color=:black)
hlines!(ax1, mouse_stop_price, linestyle=:dash, linewidth=1, color=:red)
hlines!(ax1, mouse_profit_price, linestyle=:dash, linewidth=1, color=:green)

# 止赢、止损、开仓对应价格
mouse_open_price_text = @lift string($long_or_short == "LONG" ? "做多" : "做空") * ": " * string($mouse_open_price) * "/" * string($quantity)
mouse_stop_price_text = @lift "止损: " * string($mouse_stop_price)
mouse_profit_price_text = @lift "止赢: " * string($mouse_profit_price)

# 止赢、止损、开仓线以及对应价格
text!(ax1, mouse_text_coor, mouse_open_price, text=mouse_open_price_text, color=:black)
text!(ax1, mouse_text_coor, mouse_stop_price, text=mouse_stop_price_text, color=:red)
text!(ax1, mouse_text_coor, mouse_profit_price, text=mouse_profit_price_text, color=:green)

scatter!(ax1, mouse_pos; markersize=10, color=:red)
xlims!(ax1, x_min, x_max)
# ylims!(ax1, y_min[], y_max[])


# menus 
menu_symbol = Menu(fig, options=best_trading_pairs,
    default=coin_pair[])
menu_time_interval = Menu(fig, options=["1m", "5m", "15m", "30m", "1h", "4h"], default=time_interval[])
menu_leverage = Menu(fig, options=zip(["3", "5", "8", "10"], [3, 5, 8, 10]), default=string(leverage[]))
menu_stop = Menu(fig, options=zip(["1", "2", "3", "4", "5", "10", "100", "200"], [1e-3, 2e-3, 3e-3, 4e-3, 5e-3, 1e-2, 1e-1, 2e-1]), default=string(Int(stop_pct[] * 1000)))
menu_profit = Menu(fig, options=zip(["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], [1e-3, 2e-3, 3e-3, 4e-3, 5e-3, 6e-3, 7e-3, 8e-3, 9e-3, 1e-2]), default=string(Int(profit_pct[] * 1000)))

# 右边菜单
fig[1:vratio+1, hratio+1] = vgrid!(
    Label(fig, "币对", width=nothing), menu_symbol,
    Label(fig, "周期", width=nothing), menu_time_interval,
    Label(fig, "杠杆", width=nothing), menu_leverage,
    Label(fig, "止损 ‰", width=nothing), menu_stop,
    Label(fig, "止赢 ‰", width=nothing), menu_profit,
    Label(fig, text_long_or_short, width=nothing, color=text_long_or_short_color),
    Label(fig, text_balance, width=nothing),
    Label(fig, text_unPnL, width=nothing),
    Label(fig, text_liq_price, width=nothing),
    Label(fig, text_position_amount, width=nothing),
    Label(fig, text_open_price, width=nothing),
    Label(fig, text_stop_price, width=nothing),
    Label(fig, text_profit_price, width=nothing);
    tellheight=false)

# 选择币对
on(menu_symbol.selection) do s
    coin_pair[] = s
    ylims!(ax1, y_min[], y_max[])
end

# 选择杠杆
on(menu_leverage.selection) do s
    leverage[] = s
    change_leverage(user, coin_pair[], leverage[])
end

# 选择止损比例
on(menu_stop.selection) do s
    stop_pct[] = s
    if has_position[]
        if has_stop_order[]
            cancel_stop_order(user, coin_pair[])
        end
        _stop_price = round(cal_sto_price(long_or_short[], position_price[], stop_pct[]), digits=price_precision[])
        stop_order_dict = create_stop_order_dict(coin_pair[], stop_order_side[], position_amount[], _stop_price, long_or_short[])
        execute_order(stop_order_dict, user)
    end
end

# 选择止盈比例
on(menu_profit.selection) do s
    profit_pct[] = s
    if has_position[]
        if has_profit_order[]
            cancel_profit_order(user, coin_pair[])
        end
        _profit_price = round(cal_profit_price(long_or_short[], position_price[], profit_pct[]), digits=price_precision[])
        profit_order_dict = create_profit_order_dict(coin_pair[], stop_order_side[], position_amount[], _profit_price, long_or_short[])
        execute_order(profit_order_dict, user)
    end
end

# 选择k线周期
on(menu_time_interval.selection) do s
    time_interval[] = s
    ylims!(ax1, y_min[], y_max[])
end

open_line = hlines!(ax1, open_price, color=:blue, linewidth=1)
stop_line = hlines!(ax1, stop_price, color=:red, linewidth=1)
profit_line = hlines!(ax1, profit_price, color=:green, linewidth=1)
liq_line = hlines!(ax1, liq_price, color=:purple, linewidth=1)
open_text = text!(ax1, order_text_coor, open_price, text=text_open_price)
stop_text = text!(ax1, order_text_coor, stop_price, text=text_stop_price)
profit_text = text!(ax1, order_text_coor, profit_price, text=text_profit_price)
liq_text = text!(ax1, order_text_coor, liq_price, text=text_liq_price)

position_line = hlines!(ax1, position_price, color=:blue, linewidth=1)
position_text = text!(ax1, order_text_coor, position_price, text=text_position_price)

# 点击键盘r键开单
on(events(ax1).keyboardbutton) do event
    if ispressed(fig, Keyboard.r) & (!has_open_order[]) & (!has_position[])
        _open_price = mouse_open_price[]
        _stop_price = mouse_stop_price[]
        _profit_price = mouse_profit_price[]
        _quantity = floor(wallet_balance[] * leverage[] * 0.99 / _open_price, digits=quantity_precision[])

        open_order_dict = create_open_order_dict(coin_pair[], order_side[], _quantity, _open_price, long_or_short[])
        # stop_order_dict = create_stop_order_dict(coin_pair[], stop_order_side[], _quantity, _stop_price, long_or_short[])
        # profit_order_dict = create_profit_order_dict(coin_pair[], stop_order_side[], _quantity, _profit_price, long_or_short[])
        execute_order(open_order_dict, user)
        # execute_order(stop_order_dict, user)
        # execute_order(profit_order_dict, user)

        coin_pair[] = coin_pair[]
    end
end

# 点击键盘c键取消所有订单
on(events(ax1).keyboardbutton) do event
    if ispressed(fig, Keyboard.c) & has_open_order[] & (!has_position[])
        cancel_all_open_orders(user, coin_pair[])
        coin_pair[] = coin_pair[]
    end
end

# 点击键盘y键一键平仓
on(events(ax1).keyboardbutton) do event
    if ispressed(fig, Keyboard.y) & has_position[]
        cancel_all_open_orders(user, coin_pair[])

        _position = position[][1]
        _long_or_short = _position["positionSide"]
        _stop_order_side = (_long_or_short == "LONG" ? "SELL" : "BUY")
        _quantity = abs(parse(Float64, _position["positionAmt"]))
        maket_order_dict = create_maket_order_dict(coin_pair[], _stop_order_side, _quantity, _long_or_short)
        execute_order(maket_order_dict, user)

        coin_pair[] = coin_pair[]
    end
end

# CCI indicator
# ax2 = Axis(fig[vratio+1, 1:hratio], title="CCI", yaxisposition=:right)
# deactivate_interaction!(ax2, :rectanglezoom)

# lines!(ax2, ACCI, color=:blue)
# vlines!(ax2, mouse_pos_x, color=:red, linestyle=:dash, linewidth=1)
# hlines!(ax2, 0, color=:black, linestyle=:dash, linewidth=0.5)
# hlines!(ax2, -70, color=:purple, linewidth=0.5)
# hlines!(ax2, -100, color=:red, linewidth=0.5)
# hlines!(ax2, 100, color=:red, linewidth=0.5)
# ylims!(ax2, -200, 200)
# linkxaxes!(ax1, ax2)

# MACD indicator
macds = @lift macd($Close)[:, 3]
max_macd = @lift maximum(skipmissing(isnan(x) ? missing : x for x in abs.($macds))) * 1.1
min_macd = @lift -$max_macd

function get_macd_colors(macds)
    macds2 = copy(macds)
    pushfirst!(macds2, NaN)
    colors = (macds[1:end] .> macds2[1:end-1])
    colors
end

macd_colors = @lift get_macd_colors($macds)

ax2 = Axis(fig[vratio+1, 1:hratio], title="MACD", yaxisposition=:right)
# deactivate_interaction!(ax2, :rectanglezoom)

vlines!(ax2, mouse_pos_x, color=:red, linestyle=:dash, linewidth=1)
hlines!(ax2, mouse_pos_y, color=:red, linestyle=:dash, linewidth=1)
barplot!(ax2, 1:kline_limit, macds, color=macd_colors, colormap=cmap)
ylims!(ax2, min_macd[], max_macd[])

linkxaxes!(ax1, ax2)
display(fig)

tt = 1
while tt < 5000
    base_coin[] = base_coin[]
    coin_pair[] = coin_pair[]
    time_interval[] = time_interval[]
    ylims!(ax1, y_min[], y_max[])

    # 如果有仓位但没有止盈单，补挂止赢单
    if (has_position[]) & (!has_profit_order[])

        _position0 = get_current_position(user, coin_pair[])
        if !(isempty(_position0))
            _position = _position0[1]
            _long_or_short = _position["positionSide"]
            _stop_order_side = (_long_or_short == "LONG" ? "SELL" : "BUY")
            _open_price = parse(Float64, _position["entryPrice"])
            _profit_price = round(cal_profit_price(_long_or_short, _open_price, profit_pct[]), digits=price_precision[])
            _quantity = abs(parse(Float64, _position["positionAmt"]))
            profit_order_dict = create_profit_order_dict(coin_pair[], _stop_order_side, _quantity, _profit_price, _long_or_short)
            execute_order(profit_order_dict, user)
        end
    end
    # sleep(0.005)
    global tt += 1
end