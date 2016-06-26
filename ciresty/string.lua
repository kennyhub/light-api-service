local _M = {}
_M._VERSION = '0.0.1'

function _M.trim(str)
  return (str:gsub("^%s*(.-)%s*$", "%1"))
end

function _M.split(str, seq, exclude_blank)
    local index = 1
    local sindex = 1
    local sarr = {}
    while true do
		local lindex = string.find(str, seq, index, true)
		local sub = '';
		if not lindex then
			sub = string.sub(str, index, string.len(str));
			if(_M.trim(sub) == '' and sindex ~= 1) then
				break;
			end
			sarr[sindex] = sub;
			break
		end
		sub = string.sub(str, index, lindex - 1);
		if (not exclude_blank) then
			sarr[sindex] = sub;
			sindex = sindex + 1
		elseif (exclude_blank and _M.trim (sub) ~= '') then
			sarr[sindex] = sub;
			sindex = sindex + 1
		end
		index = lindex + string.len(seq)
		  
    end
    return sarr
end

function _M.taken_variable(str)
	local s = string.find(str, "{", 1, true)
	if(s and s > 0) then
		local e = string.find(str, "}", s, true)
		if(e and e > 0 and e ~= s+1) then
			str = string.sub(str, s+1, e-1)
		end
	end
	return str;
end

function _M.is_blank(res)
    return res == nil or res == ngx.null or #(_M.trim(res)) == 0;
end

function _M.is_null( res )
    if type(res) == "table" then
        if(#res == 0) then
            return false;
        end
        for _,v in ipairs(res) do
            if v ~= ngx.null then
                return false
            end
        end
        return true
    elseif res == ngx.null then
        return true
    elseif res == nil then
        return true
    end
    return false
end

function _M.url_encode(str) 
	return ngx.escape_uri(str);
end

function _M.unescape_uri(str) 
	return ngx.escape_uri(str);
end

function _M.escape(str)
	if(str=='nil' or str=='' or str==nil)then
		return str;
	end
	if(string.find(str,'<', 1, true) ~= nil) then
		str = string.gsub(str, '<', '&lt;');
	end
	if(string.find(str,'>', 1, true)~=nil)then
		str= string.gsub(str, '>', '&gt;');
	end
	if(string.find(str,'"', 1, true)~=nil)then
		str= string.gsub(str, '"', '&quot;');
	end
	if(string.find(str,'&', 1, true)~=nil)then
		str= string.gsub(str, '&', '&amp;');
	end
	if(string.find(str,"'", 1, true)~=nil)then
		str= string.gsub(str, "'", '&apos;');
	end
	return str;
end

return _M