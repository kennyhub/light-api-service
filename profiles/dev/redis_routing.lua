local _M = {}
_M._VERSION = '0.0.1'

_M.cluster_price_routing = {
	host_ports = "10.185.240.142:7001;10.185.240.142:7002;10.185.240.142:7003;10.185.240.142:7004;10.185.240.142:7005;10.185.240.142:7006;"
}

_M.cluster_sample_routing = {
	host_ports = "10.185.240.132:7000;10.185.240.132:7001;10.185.240.132:7002;10.185.240.132:7003;10.185.240.132:7004;10.185.240.132:7005;"
}

_M.count_limit_routing = {
	host = "10.185.240.132", 
	port = "6379", 
	password = "foobared"
}

_M.product_routing = {
	host = "10.185.240.131", 
	port = "6679"
}

_M.scm_routing = {
	host = "10.185.240.131", 
	port = "6879"
}

_M.activity_exclusive_routing = {
	host = "10.185.240.131", 
	port = "6379"
}

_M.price_routing = {
	host = "10.185.240.131", 
	port = "6879"
}

_M.front_server_routing = {
	host = "10.185.240.131",
	port = "6979"
}

return _M