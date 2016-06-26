local _M = {}
--local http = require("resty.http")
local cistring = require("ciresty.string")
local citable = require("ciresty.table")
_M._VERSION = '0.0.1'

function _M.merge_params(ngx)
	if(ngx.req.get_method() ~= 'POST') then
		return;
	end
	ngx.req.read_body();
	local post_args = ngx.req.get_post_args();

	if(post_args ~= nil and type(post_args) == 'table') then
		ngx.req.set_uri_args(citable.merge(post_args, ngx.req.get_uri_args()));
	end
	return;
end

function _M.common_params(ngx)
	local common_params = {};
	--请求头  
	local request_headers = ngx.req.get_headers();

	common_params.app_ver = request_headers["app-ver"] or request_headers["appver"] or ngx.var.arg_c_app_ver;
	common_params.channel = request_headers["channel"] or ngx.var.arg_c_channel;
	common_params.device_id = request_headers["device-id"] or request_headers["deviceId"] or request_headers["imei"] or ngx.var.arg_c_device_id
	common_params.platform = request_headers["platform"] or request_headers["deviceModel"] or ngx.var.arg_c_platform
	common_params.platform_ver = request_headers["platform-ver"] or request_headers["iosVersion"] or request_headers["sysver"] or ngx.var.arg_c_platform_ver
	common_params.upk = request_headers["upk"] or ngx.var.arg_upk or ngx.var.arg_c_upk

	local platform_type = request_headers["platform-type"] or request_headers["product"] or ngx.var.arg_c_platform_type;
	if ngx.re.find(tostring(platform_type), '^[0-5]$') then
		platform_type = tonumber(platform_type)
	else
		platform_type = -1
	end
	common_params.platform_type = platform_type

	common_params.nonce = ngx.var.arg_nonce
	common_params.timestamp = ngx.var.arg_timestamp
	common_params.version = ngx.var.arg_version

	return common_params;

end

function _M.remote_ip(ngx)
	local remoteIP = ngx.var.remote_addr
	if(string.find(remoteIP, '119%.188%.35%.%d+') ~= nil
		or string.find(remoteIP, '222%.240%.184%.%d+') ~= nil
		or string.find(remoteIP, '218%.65%.212%.%d+') ~= nil
		or string.find(remoteIP, '116%.211%.121%.%d+') ~= nil
		or string.find(remoteIP, '183%.60%.85%.%d+') ~= nil
		or string.find(remoteIP, '180%.96%.20%.%d+') ~= nil
		or string.find(remoteIP, '112%.25%.16%.%d+') ~= nil
		or string.find(remoteIP, '103%.1%.65%.%d+') ~= nil
		or string.find(remoteIP, '61%.155%.222%.%d+') ~= nil
		or string.find(remoteIP, '61%.240%.149%.%d+') ~= nil
		or string.find(remoteIP, '121%.14%.143%.%d+') ~= nil
		or string.find(remoteIP, '203%.90%.247%.%d+') ~= nil
		or string.find(remoteIP, '209%.9%.130%.%d+') ~= nil
		or string.find(remoteIP, '42%.62%.98%.%d+') ~= nil
		or string.find(remoteIP, '59%.52%.28%.%d+') ~= nil
		or string.find(remoteIP, '120%.132%.64%.%d+') ~= nil
		or string.find(remoteIP, '113%.207%.76%.%d+') ~= nil
		or string.find(remoteIP, '203%.90%.230%.%d+') ~= nil
		or string.find(remoteIP, '123%.151%.182%.%d+') ~= nil
		or string.find(remoteIP, '218%.60%.62%.%d+') ~= nil
		or string.find(remoteIP, '42%.48%.109%.%d+') ~= nil
		or string.find(remoteIP, '42%.236%.72%.%d+') ~= nil
		or string.find(remoteIP, '117%.21%.219%.%d+') ~= nil
		or string.find(remoteIP, '218%.75%.177%.%d+') ~= nil
		or string.find(remoteIP, '210%.76%.61%.%d+') ~= nil
		or string.find(remoteIP, '113%.200%.91%.%d+') ~= nil
		or string.find(remoteIP, '153%.37%.232%.%d+') ~= nil
		or string.find(remoteIP, '117%.23%.1%.%d+') ~= nil
		or string.find(remoteIP, '220%.167%.107%.%d+') ~= nil
		or string.find(remoteIP, '111%.202%.98%.%d+') ~= nil
		or string.find(remoteIP, '113%.107%.238%.%d+') ~= nil
		or string.find(remoteIP, '106%.42%.25%.%d+') ~= nil
		or string.find(remoteIP, '219%.153%.73%.%d+') ~= nil ) then
		local xff = ngx.req.get_headers()["X-Forwarded-For"]
		if(xff ~= nil and #xff > 0) then
			local xffs = cistring.split(xff, ",", true);
			remoteIP = table.remove(xffs)	
		end
	end
	return remoteIP
end

return _M