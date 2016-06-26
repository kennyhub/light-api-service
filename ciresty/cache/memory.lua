local _M = {}
_M._VERSION = '0.0.1'

local citable = require 'ciresty.table';
local cache = {};

function _M.get(key, field)
	if type(cache) ~= 'table' then
		cache = {}
	end
	local value, flags = cache[field]
	if value == ngx.null then
		return nil, 0;
	end
	return value;
end

function _M.set(key, field, value, exptime)
	if type(cache) ~= 'table' then
		cache = {}
	end
	if value == ngx.null then 
		value = nil;
	end
	cache[field] = value;
	local function expires(premature, field)
		--table.remove(cache, field)
		cache[field] = nil;
	end
	local ok, err = ngx.timer.at((exptime or 60), expires, field)
	if err then
		ngx.log(ngx.ERR, "memory_cache expires fail！"..err)
	end
	return true, #cache;
end

return _M