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