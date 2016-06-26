local _M = {}
_M._VERSION = '0.0.1'

local citable = require 'ciresty.table';
local cjson = require 'ciresty.cjson';

function _M.get(key, field)
	local cache = ngx.shared[key];
	local value, flags = cache:get(field)
	if value == ngx.null then
		return nil, 0;
	end
	flags = flags or 0;
	if flags == 1 then
		value = cjson.decode(value);
	end
	return value, flags;
end

function _M.set(key, field, value, exptime)
	exptime = exptime or 0;
	local flags = 0;
	if type(value) == "table" then 
		value = cjson.encode(value);
		flags = 1;
	end
	if value == ngx.null then 
		value = nil;
	end
	local cache = ngx.shared[key];
	local succ, err, forcible = cache:safe_set(field, value, exptime, flags)
	return succ, err, forcible;
end

return _M