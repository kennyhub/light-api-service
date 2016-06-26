local _M = {}
_M._VERSION = '0.0.1'
local cjson = require "ciresty.cjson"

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end
_M.new_tab = new_tab;

local ok, clear_tab = pcall(require, "table.clear")
if not ok then
    clear_tab = function(tab) for k, _ in pairs(tab) do tab[k] = nil end end
end
_M.clear_tab = clear_tab;

local function is_table(hash)
	return hash ~= nil and type(hash) == 'table'
end

local function is_empty_hash(hash)
	for _,_ in pairs(hash) do
		return false;
	end
	return true;
end

function _M.is_not_empty(hash)
	if not is_table(hash) then
		return nil
	end
	return not is_empty_hash(hash)
end

function _M.is_empty(hash)
	if not is_table(hash) then
		return nil
	end
	return #hash == 0 and is_empty_hash(hash)
end

function _M.contains_key(hash, key)
	return _M.index_of_value(hash, value) ~= nil
end

function _M.contains_value(hash, value)
	return _M.index_of_key(hash, value) ~= nil
end

function _M.index_of_key(hash, value)
	if not is_table(hash) then
		return nil
	end
	for k,v in pairs(hash) do
		repeat
			if (v == nil or v == ngx.null) then
				break;
			end	
			if (v == value) then
				return k;
			end
		until true
	end
	return nil
end

function _M.index_of_value(hash, key)
	if not is_table(hash) then
		return nil
	end
	for k,v in pairs(hash) do
		if (k == key) then
			return v;
		end
	end
	return nil
end

function _M.size(hash)
	if not is_table(hash) then
		return 0
	end
    local size = 0
    for k, v in pairs(hash) do
        size = size + 1
    end
    return size
end

function _M.keys(hash)
    local keys = {}
    if not is_table(hash) then
        return keys;
    end
    for k, _ in pairs(hash) do
        keys[#keys + 1] = k
    end
    return keys
end

function _M.values(hash)
    local values = {}
    if not is_table(hash) then
        return values;
    end
    for _, v in pairs(hash) do
        values[#values + 1] = v
    end
    return values
end

function _M.assemble(key_list, value_list)
	if not is_table(key_list) or not is_table(value_list) then
    	return {}
	end
	local hash = _M.new_tab(0, #key_list)
	for i = 1, #key_list do
		hash[key_list[i]] = value_list[i]
	end
    return hash 	
end

function _M.add_all(source_list, target_list)
	if not is_table(source_list) and not is_table(target_list) then
        return {}
    elseif not is_table(source_list) then
    	return target_list
	elseif not is_table(target_list) then
		return source_list
	end
	local source_index = table.maxn(source_list);

	local i = 1;
	for _, v in pairs(target_list) do
		source_list[source_index+i] = v
		i = i + 1;
	end

    return source_list 	
end

function _M.merge(source, target)
	if not is_table(source) and not is_table(target) then
        return {}
    elseif not is_table(source) then
    	return target
	elseif not is_table(target) then
		return source
	end
 --	   for k, v in pairs(source) do
 --        if (type(v) == "table") and (type(target[k] or false) == "table") then
 --            merge(source[k], target[k])
 --        else
 --            target[k] = v
 --        end
 --    end
 	for k,v in pairs(source) do target[k] = v end
    return target 	
end

function _M.merges(source, targets)
	if not is_table(source) and not is_table(targets) then
        return {}
    elseif not is_table(source) then
    	return target
	elseif not is_table(targets) then
		return source
	end
	for i = 1, #targets do
		source = _M.merge(source, targets[i])
	end
    return source 	
end

function _M.clone(hash)
	if not is_table(hash) then
        return {}
    end
    local target = {}
    for k, v in pairs(hash) do
        if not is_table(v) then
            target[k] = v
        else
            target[k] = clone(v)
        end
    end
    return target
end


return _M