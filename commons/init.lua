local citable = require 'ciresty.table';
local cistring = require 'ciresty.string';
local cihttp = require 'ciresty.http';
local cjson = require 'ciresty.cjson';
local cidate = require "ciresty.date"
local ciredis = require "ciresty.redis"
local ciredisc = require "ciresty.redis.cluster"
local cilimits = require "ciresty.limits"
local cicount = require "ciresty.count"
local cifile = require "ciresty.file"

local _M = {}
_M._VERSION = '0.0.1'

local function init_profiles(env, custom_package_path)
	local env_config = env or "dev";
	if 'dev' ~= env_config and 'test' ~= env_config and 'pro' ~= env_config then
		env_config = "dev"
	end
	local profiles = {
		'redis_routing.lua'
	}

	local source_path = custom_package_path..'profiles/'..env_config..'/';
	local target_path = custom_package_path..'profiles/';
	for i = 1, #profiles do
		local profile = profiles[i]
		local ok, err = cifile.copy(source_path..profile, target_path..profile)
		if err then
			ngx.log(ngx.ERR, 'openresty启动失败，配置文件['..profile..']复制路径['..custom_package_path..'], '..err)
		end
	end
end

function _M.init(params)
	params = params or {};
	init_profiles(params.env, params.custom_package_path);
end

return _M