local outputstr, eof = ngx.arg[1],ngx.arg[2];

-- local is_van_chunked = ngx.ctx.is_van_chunked
-- if not is_van_chunked then
-- 	local callback = ngx.var.arg_callback;
-- 	if(callback ~= nil and #(callback) > 0) then
-- 		ngx.ctx.is_van_chunked = true;
-- 		outputstr = tostring(callback) .. '(' .. outputstr;
-- 	end
-- end
-- if eof then 
-- 	outputstr = outputstr .. ')'
-- end
-- ngx.arg[1] = outputstr

local ngx_ctx = ngx.ctx
local chunked_body = ngx_ctx.chunked_body or {}

if type(chunked_body) ~= 'table' then
	chunked_body = {}
end
table.insert(chunked_body, outputstr)
ngx_ctx.chunked_body = chunked_body
if eof then 
	outputstr = table.concat(chunked_body, '');

	local sub_modules_body_filter = ngx_ctx.API_SUB_MODULE_BODY_FILTER
	if sub_modules_body_filter and type(sub_modules_body_filter) == 'table' and #sub_modules_body_filter > 0 then
		for i = 1, #sub_modules_body_filter do
			repeat
				local sub_module = sub_modules_body_filter[i]
				if not sub_module or #sub_module == 0 then
					break
				end
		    	local sub_body_filter = require(sub_module)
		    	outputstr = sub_body_filter.executor(outputstr);
			until true
		end
	end
	local callback = ngx.var.arg_callback;
	if(callback ~= nil and #(callback) > 0) then
		outputstr = tostring(callback) .. '(' .. outputstr .. ')'
	end
	ngx.arg[1] = outputstr
else
	ngx.arg[1] = ''
end
