local _M = {}
_M._VERSION = '0.0.1'

_M.cluster_price_routing = {
	host_ports = "192.168.60.59:7001;192.168.60.59:7002;192.168.60.60:7001;192.168.60.60:7002;192.168.60.61:7001;192.168.60.61:7002"
}

_M.count_limit_routing = {
	host = "192.168.60.217", 
	port = "6979"
}

_M.product_routing = {
	host = "100.168.70.216",
	port = "6679"
}

_M.scm_routing = {
	host = "192.168.60.216",
	port = "6879"
}

_M.activity_exclusive_routing = {
	host = "192.168.70.211",
	port = "6379"
}

_M.front_server_routing = {
	host = "192.168.60.217",
	port = "6979"
}

return _M