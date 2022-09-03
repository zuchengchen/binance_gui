"""
Convert datetime to string.
"""
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
timestamp_to_datetime(ts) = Dates.unix2datetime(ts / 1000)


"""
Return the timestamp of now in the units of milliseconds.
"""
timestamp_now() = datetime_to_timestamp(datetime_now())