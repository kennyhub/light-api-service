local _M = {}
_M._VERSION = '0.0.1'

local lrucache = require "resty.lrucache";
local c = lrucache.new(20000);
local citable = require 'ciresty.table';
local cjson = require 'ciresty.cjson';

function _M.get(key, field)
	if not c then
	    return nil, 'failed to create the cache'
	end
	return c:get(field)
end

function _M.set(key, field, value, exptime)
	exptime = exptime or 0;
	c:set(field, value, exptime)
end

return _M