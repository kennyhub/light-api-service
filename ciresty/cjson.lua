local _M = {}
_M._VERSION = '0.0.1'
local _MAX_ENCODE_SUB_DEPTH = 10;

local cjson = require 'cjson.safe';

local methods = {
	"encode_empty_table_as_object",
	"encode_number_precision",
	"encode_sparse_array",
	"decode"
}

for i = 1, #methods do
    local method = methods[i]
    _M[method] = function (self, ...)
        return cjson[method](self, ...);
    end
end

local variables = {
	"empty_array",
	"empty_array_mt"
}

for i = 1, #variables do
    local variable = variables[i]
    _M[variable] = cjson[variable];
end

function _M.encode(hashtable, ...)
	local settings = {...};
	settings = #settings > 0 and settings[1] or {};
	local fields = settings.fields;
	local depth = settings.depth;
	local empty_table_object = settings.empty_table_object;
	
	hashtable = _M.sub_table(hashtable, fields, depth);
	if(cjson.encode_empty_table_as_object and empty_table_object ~= nil) then
		cjson.encode_empty_table_as_object(empty_table_object);
	end
	return cjson.encode(hashtable);
end

function _M.sub_table(hashtable, fields, depth)
	if (fields == nil or (type(fields) == 'string' and #(fields) == 0)) then
		return hashtable;
	end
	if (type(hashtable) ~= 'table') then
		return hashtable;
	end
	if(string.byte(fields) ~= string.byte(',')) then
		fields = ',' .. fields;
	end
	if(string.byte(fields, #(fields)) ~= string.byte(',')) then
		fields = fields .. ',';
	end
	local hash = {};
	for k,v in pairs(hashtable) do
		repeat
			if (v == nil or v == ngx.null) then
				break;
			end	
			-- hashtable是一个hash结构
			if(type(k) ~= 'number') then
				if(string.find(fields, ','..k..',', 1, true)) then
					hash[k] = v;
				end
				break;
			end
			-- hashtable是list结构，子级不是hash结构
			if(type(k) == 'number' and type(v) ~= 'table') then
				table.insert(hash, v);
				break;
			end
			depth = depth and type(depth) ~= 'number' or 0;
			if(depth <= _MAX_ENCODE_SUB_DEPTH) then
				v = _M.sub_table(v, fields, (depth+1));
			end
			table.insert(hash, v);
		until true
	end
	return hash
end

return _M