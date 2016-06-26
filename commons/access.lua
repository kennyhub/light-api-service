local cihttp = require "ciresty.http"
local cilimits = require "ciresty.limits"
local ciredis = require "ciresty.redis"
local cjson = require "ciresty.cjson"
local routing = require "profiles.redis_routing"
local cidate = require "ciresty.date"
local start = cidate.current_millisecond(ngx)

local redis = ciredis:new(routing.count_limit_routing);

local remote_ip = cihttp.remote_ip(ngx);
ngx.ctx.remote_ip = remote_ip

local uri = ngx.var.custom_content_file or ngx.var.uri

local limits = cilimits:new({rds=redis});

local is_black_lists = limits:block_black_lists({black_lists_rds_key="LIMITS::BALCK_LISTS", white_lists_rds_key="LIMITS::WHITE_LISTS", ip=remote_ip})

if is_black_lists then
	ngx.print([[{"retCode":400004,"retMsg":"Due to frequent connections, your IP is temporarily banned. "}]])
	ngx.exit(ngx.HTTP_OK)
elseif is_black_lists == nil then
	--加用户id
	local block_limit, second = limits:limit({rate="100r/s", key=remote_ip.."::"..uri})
	if block_limit then
		local retry_message = second and second > 0 and ("after "..second.." seconds .") or "later .";
		ngx.print([[{"retCode":400003,"retMsg":"Due to frequent connections, Please try again ]]..retry_message..[["}]])
		ngx.exit(ngx.HTTP_OK)
	end
end