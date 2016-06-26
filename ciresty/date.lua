local _M = {}
_M._VERSION = '0.0.1'

function _M.parse(date_str)
	if not date_str then
		return 0
	end
	local Y = string.sub(date_str,1,4)
	local M = string.sub(date_str,6,7)
	local D = string.sub(date_str,9,10)
	local H,MM,SS = 0,0,0;
	if(string.len(date_str) > 10) then
		H = string.sub(date_str,12,13)
		MM = string.sub(date_str,15,16)
		SS = string.sub(date_str,18,19)
	end

	local now = os.time{year=Y, month=M, day=D, hour=H,min=MM,sec=SS};
	return now*1000;
end
function _M.format(seconds, pattern)
	if(seconds == nil) then
		seconds = os.time();	
	end
	seconds = tonumber(seconds)
	if(seconds == nil) then
		return nil
	end
	pattern = pattern or "%Y-%m-%d %H:%M:%S"
	return os.date(pattern, seconds)
end

function _M.current_millisecond(ngx)
	return ngx and ngx.now()*1000
end

function _M.current_second(ngx)
	return ngx and ngx.time(ngx)
end

function _M.current_date(ngx)
	return ngx and ngx.today(ngx)
end

function _M.current_datetime()
	return ngx and ngx.localtime(ngx)
end

function _M.current_utc_datetime(ngx)
	return ngx and ngx.utctime()
end

function _M.current_second(ngx)
	return ngx and ngx.now()
end


return _M