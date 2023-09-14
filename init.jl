# add CairoMakie, Random, TimeSeries, Dates, GLMakie, DataFrames, DataStructures, ProgressMeter, JSON, HTTP, SHA, Printf, CSV, Indicators
# using CairoMakie, Random, TimeSeries, GLMakie, DataFrames, DataStructures, ProgressMeter
using CairoMakie, GLMakie, DataFrames
using Statistics
import HTTP, JSON, SHA, CSV, Indicators, Dates

const Float = Float64
const ID = Indicators
const recvWindow = 60000

include("urls.jl")
include("time.jl")
include("utils.jl")
include("kline.jl")
include("account.jl")
include("order.jl")
include("indicator.jl")