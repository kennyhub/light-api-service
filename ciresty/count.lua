local _M = {}
_M._VERSION = '0.0.1'

local citable = require "ciresty.table"
local cidate = require "ciresty.date"

local _M = citable.new_tab(0, 155)
local mt = { __index = _M }

function _M.qps(settings)
    local uri = settings.uri;
    local ip = settings.ip;
	local rds = settings.rds
    if not rds then
    	return false
    end

    local today = cidate.current_date(ngx);

    local uv_ip_key = "COUNT::UV::IP::"..ip
    local uv_uri_key = "COUNT::UV::URI::"..uri

    local pv_ip_key = "COUNT::PV::IP::"..ip
    local pv_uri_key = "COUNT::PV::URI::"..uri

    local today_uv_ip_key = uv_ip_key.."::"..today
    local today_uv_uri_key = uv_uri_key.."::"..today

    local today_pv_ip_key = pv_ip_key.."::"..today
    local today_pv_uri_key = pv_uri_key.."::"..today

    local ip_queues_key = "COUNT::IP-QUEUES"
    local uri_queues_key = "COUNT::URI-QUEUES"

    rds:init_pipeline();

    rds:sadd(ip_queues_key, ip);
    rds:sadd(uri_queues_key, uri);

    rds:incr(pv_ip_key);
    rds:incr(pv_uri_key);

    rds:incr(today_pv_ip_key);
    rds:expire(today_pv_ip_key, 60*60*24*7)
    rds:incr(today_pv_uri_key);
    rds:expire(today_pv_uri_key, 60*60*24*7)

    rds:pfadd(uv_ip_key, uri)
    rds:pfadd(uv_uri_key, ip)

    rds:pfadd(today_pv_ip_key, uri);
    rds:expire(today_pv_ip_key, 60*60*24*7)
    rds:pfadd(today_pv_uri_key, ip);
    rds:expire(today_pv_uri_key, 60*60*24*7)

    rds:commit_pipeline();

    return true;
end

return _M