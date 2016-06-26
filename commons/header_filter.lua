local cct = ngx.var.custom_content_type;
if (cct ~= nil and cct == 'json') then
	ngx.header.content_type = [[application/json; charset=utf-8]]
else
	ngx.header.content_type = [[text/html; charset=utf-8]]
end