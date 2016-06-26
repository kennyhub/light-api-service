local _M = {}
_M._VERSION = '0.0.1'

function _M.copy(source_path, target_path)
	local source_file = pcall(io.input, source_path)
	if not source_file then 
		return nil, (source_path.."不存在") 
	end
	local str = io.read("*a")
	local target_file = io.output(target_path)
	io.write(str)
	io.flush()
	io.close() 
	return 'ok', nil
end

return _M