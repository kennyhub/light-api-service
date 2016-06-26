local _M = {}
_M._VERSION = '0.0.1'

local citable = require "ciresty.table"

local _M = citable.new_tab(0, 155)
local mt = { __index = _M }

local redis_limit_script_sha
local redis_limit_script = [==[
    local key, scale, rate = KEYS[1], tonumber(KEYS[2]), tonumber(KEYS[3])
    redis.pcall('set', key, 0, "EX", scale, "NX")
    local res = redis.pcall('incr', key)
    if res and tonumber(res) > rate then
        local expire = redis.pcall('ttl', key)
        if expire and expire == -1 then
            expire = scale
            redis.pcall('expire', key, expire)
        end
        return expire;
    end
    return ;
]==]

function _M.new(self, settings)
    local rds = settings and settings.rds;

    return setmetatable({rds=rds}, mt)
end

local function execute_script(rds, key, scale, rate)
    if not redis_limit_script_sha then
        local res, err = rds:script("LOAD", redis_limit_script)
        if not res then
            return false, 0
        end
        redis_limit_script_sha = res
    end
    local res, err = rds:evalsha(redis_limit_script_sha, 3, key, scale, rate)
    if not res then
        redis_limit_script_sha = nil
        return false, 0
    end
    return true, tonumber(res)
end

function _M.limit(self, settings)
    local key = settings.key;
    local rate = settings.rate or "1r/s";

	local rds = self.rds
    if not rds then
    	return false,0;
    end

    local scale = 1
    local len = #rate

	if len > 3 then
	    if rate:sub(len - 2) == "r/s" then
	        scale = 1
	        rate = rate:sub(1, len - 3)
	    elseif rate:sub(len - 2) == "r/m" then
	        scale = 60
	        rate = rate:sub(1, len - 3)
	    elseif rate:sub(len - 2) == "r/h" then
	        scale = 60*60
	        rate = rate:sub(1, len - 3)
	    elseif rate:sub(len - 2) == "r/d" then
	        scale = 60*60*24
	        rate = rate:sub(1, len - 3)
	    end
	end

    --rate = floor((tonumber(rate) or 1) * 1000 / scale)
	rate = (tonumber(rate) or 1)
    key = "LIMITS::"..key
    -- rds:set(key, 0, "EX", scale, "NX")
    -- if (rds:incr(key) > rate) then
    -- 	local expire = rds:ttl(key);
    -- 	if(expire == -1) then
    -- 		expire = scale
    -- 		rds:expire(key, expire)
    -- 	end
    -- 	return true,expire;
    -- end
    -- return false,0;
    return execute_script(rds, key, scale, rate);
end

function _M.block_black_lists(self, settings)
	local black_lists_rds_key = settings.black_lists_rds_key 
    local white_lists_rds_key = settings.white_lists_rds_key 
    local ip = settings.ip
    local rds = self.rds
    if not rds then
    	return nil;
    end
    if(white_lists_rds_key) then
    	local is_white_lists = rds:sismember(white_lists_rds_key, ip) 
    	if is_white_lists ~= nil and is_white_lists == 1 then
    		return false;
    	end
    end
    if(black_lists_rds_key) then
    	local is_black_lists = rds:sismember(black_lists_rds_key, ip) 
    	if is_black_lists ~= nil and is_black_lists == 1 then
    		return true;
    	end
    end
    return nil;
end

function _M.add_black_lists(self, settings)
	local black_lists_rds_key = settings.black_lists_rds_key 
    local ip = settings.ip
    local rds = self.rds
    if not rds then
    	return false;
    end
    if(black_lists_rds_key) then
    	rds:sadd(black_lists_rds_key, ip) 
		return true;
    end
    return false;
end



return _M