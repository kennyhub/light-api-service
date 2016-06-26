local cihttp = require "ciresty.http"
local routing = require "profiles.redis_routing"
local ciredis = require "ciresty.redis"
local cicount = require 'ciresty.count'

local redis = ciredis:new(routing.count_limit_routing);
local remote_ip = ngx.ctx.remote_ip --cihttp.remote_ip(ngx);
local uri = ngx.var.custom_content_file or ngx.var.uri

local function handler(premature)
	cicount.qps({rds=redis, ip=remote_ip, uri=uri});
end
local ok, err = ngx.timer.at(0, handler)
if err then
	ngx.log(ngx.ERR, "log_by_lua save fail！"..err)
end