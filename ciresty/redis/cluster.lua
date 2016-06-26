local ciredis = require "ciresty.redis"
local cistring = require "ciresty.string"
local citable = require "ciresty.table"
local bit = require "bit"
local cjson = require "ciresty.cjson"
local cicache = require "ciresty.cache.memory"

local _M = citable.new_tab(0, 255)
_M._VERSION = '0.0.1'
local _MASTER_NODE_INDEX, _MAX_SLOT_NUM, _CLUSTER_CACHE_DICT_KEY = 2, 16384, "cluster_cache_dict";
local cluster_nodes, cluster_slots = {}, {};

local mt = { __index = _M }

local LOOKUP_TABLE = {0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5,
    0x60C6, 0x70E7, 0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF, 0x1231,
    0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6, 0x9339, 0x8318, 0xB37B, 0xA35A,
    0xD3BD, 0xC39C, 0xF3FF, 0xE3DE, 0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4,
    0x5485, 0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D, 0x3653, 0x2672,
    0x1611, 0x0630, 0x76D7, 0x66F6, 0x5695, 0x46B4, 0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF,
    0xE7FE, 0xD79D, 0xC7BC, 0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,
    0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B, 0x5AF5, 0x4AD4, 0x7AB7,
    0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12, 0xDBFD, 0xCBDC, 0xFBBF, 0xEB9E, 0x9B79, 0x8B58,
    0xBB3B, 0xAB1A, 0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41, 0xEDAE,
    0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49, 0x7E97, 0x6EB6, 0x5ED5, 0x4EF4,
    0x3E13, 0x2E32, 0x1E51, 0x0E70, 0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59,
    0x8F78, 0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F, 0x1080, 0x00A1,
    0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067, 0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D,
    0xD31C, 0xE37F, 0xF35E, 0x02B1, 0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256,
    0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D, 0x34E2, 0x24C3, 0x14A0,
    0x0481, 0x7466, 0x6447, 0x5424, 0x4405, 0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E,
    0xC71D, 0xD73C, 0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634, 0xD94C,
    0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB, 0x5844, 0x4865, 0x7806, 0x6827,
    0x18C0, 0x08E1, 0x3882, 0x28A3, 0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB,
    0xBB9A, 0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92, 0xFD2E, 0xED0F,
    0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9, 0x7C26, 0x6C07, 0x5C64, 0x4C45, 0x3CA2,
    0x2C83, 0x1CE0, 0x0CC1, 0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8,
    0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0};

local commands = {
    "set",                  "get",                  "exists",
    "persist",              "type",                 "expire",
    "pexpire",              "expireat",             "pexpireat",
    "ttl",                  "pttl",                 "setbit",
    "getbit",               "setrange",             "getrange",
    "getset",               "setnx",                "setex",
    "psetex",               "decrby",               "decr",
    "incrby",               "incrbyfloat",          "incr",
    "append",               "substr",               "hset",
    "hget",                 "hsetnx",               "hmset",
    "hmget",                "hincrby",              "hincrbyfloat",
    "hexists",              "hdel",                 "hlen",
    "hkeys",                "hvals",                "rpush",
    "lpush",                "llen",                 "lrange",
    "ltrim",                "lindex",               "lset",
    "lrem",                 "lpop",                 "rpop",
    "sadd",                 "smembers",             "srem",
    "spop",                 "scard",                "sismember",
    "srandmember",          "strlen",               "zadd",
    "zrange",               "zrem",                 "zincrby",
    "zrank",                "zrevrank",             "zrevrange",
    "zrangewithscores",     "zrevrangewithscores",  "zcard",
    "zscore",               "sort",                 "zcount",
    "zrangebyscore",        "zrevrangebyscore",     "zrangebyscorewithscores",
    "zrevrangebyscorewithscores","zremrangebyrank", "zremrangebyscore",
    "zlexcount",            "zrangebylex",          "zrevrangebylex",
    "zremrangebylex",       "linsert",              "lpushx",
    "rpushx",               "del",                  "echo",
    "bitcount",             "bitpos",               "sscan",
    "zscan",                "pfadd",                "pfcount",
    "blpop",                "brpop",                "mget",
    "mset",                 "msetnx",               "rename",
    "renamenx",             "rpoplpush",            "sdiff",
    "sdiffstore",           "sinter",               "sinterstore",
    "smove",                "sunion",               "sunionstore",
    "zinterstore",          "zunionstore",          "brpoplpush",
    "publish",              "subscribe",            "psubscribe",
    "bitop",                "pfmerge",              "eval",
    "evalsha",              "scriptexists",         "scriptload",
    "move",                 "geoadd",               "geodist",
    "geohash",              "geopos",               "georadius",
    "georadiusbymember"
}

local function _generate_host_port_key(...)
    local settings = {...};
    settings = #settings > 0 and settings[1] or {};
    return settings.host .. ":" ..settings.port
end

local function _generate_host_ports(host_ports_str, ...)
    local host_ports = cistring.split(host_ports_str, ";", true);
    local host_port_list = citable.new_tab(0, #host_ports)
    for i = 1, #host_ports do
        local host_port = cistring.split(host_ports[i], ":", true)
        host_port_list[i] = {};
        host_port_list[i].host = host_port[1];
        host_port_list[i].port = host_port[2];
    end
    return host_port_list
end

local function _crc_16(key)
    key = cistring.taken_variable(key);
    local crc = 0x0000;
    for i = 1, #key do
        crc = bit.bxor(bit.lshift(crc, 8), LOOKUP_TABLE[bit.band(bit.bxor(bit.arshift(crc, 8), bit.band(string.byte(key, i), 0xFF)), 0xFF)+1])
    end
    return bit.band(crc, 0xFFFF)
end

local function _key_slot(key, ...)
    return bit.band(_crc_16(key),(_MAX_SLOT_NUM - 1))
end

local function _assigned_slots_nums(slot_info)
    local slot_nums = citable.new_tab(0, (slot_info[2]-slot_info[1]+10))
    local index = 1;
    for i = slot_info[1], slot_info[2] do
        slot_nums[index] = i;
        index = index + 1
    end 
    return slot_nums;
end

local function _assigned_cluster_node(target_node_key, settings)
    if(citable.contains_key(cluster_nodes, target_node_key)) then
        return;
    end
    local host_port_list = _generate_host_ports(target_node_key);
    local redis_settings = citable.clone(settings);
    redis_settings.host = host_port_list[1].host;
    redis_settings.port = host_port_list[1].port;
    redis_settings.host_ports = nil;
    cluster_nodes[target_node_key] = redis_settings;
end

local function _assigned_slots_node(slot_nums, target_node_key)
    local redis_settings = cluster_nodes[target_node_key]
    for i = 1, #slot_nums do
        cluster_slots[tonumber(slot_nums[i])+1] = redis_settings
    end
end

local function _discover_slots(redis)
    citable.clear_tab(cluster_slots)

    local slots = redis:cluster_slots();
    for i = 1, #slots do
        local slot_info = slots[i]
        repeat
            if(type(slot_info) ~= "table" or (type(slot_info) == "table" and #slot_info <= _MASTER_NODE_INDEX)) then
                break;
            end
            local slot_nums = _assigned_slots_nums(slot_info)
            local host_info = slot_info[_MASTER_NODE_INDEX+1];
            if(type(host_info) ~= "table" or (type(host_info) == "table" and #host_info <= 0)) then
                break;
            end
            local target_node_key = _generate_host_port_key({host=host_info[1], port=host_info[2]})
            _assigned_cluster_node(target_node_key, redis)
            _assigned_slots_node(slot_nums, target_node_key)
        until true
    end
end

local function _renew_slots_cache(redis, ...)
    ngx.log(ngx.ERR, '>>>> _renew_slots_cache')
    _discover_slots(redis);
end

local function _discover_nodes_slots(redis, settings)
    ngx.log(ngx.ERR, '>>>> _discover_nodes_slots')
    citable.clear_tab(cluster_nodes)
    citable.clear_tab(cluster_slots)

    local slots = redis:cluster_slots();
    if not slots then
        return
    end
    for i = 1, #slots do
        local slot_info = slots[i]
        repeat
            if(type(slot_info) ~= "table" or (type(slot_info) == "table" and #slot_info <= _MASTER_NODE_INDEX)) then
                break;
            end
            local slot_nums = _assigned_slots_nums(slot_info)
            for j = _MASTER_NODE_INDEX+1, #slot_info do
                local host_info = slot_info[j];
                repeat
                    if(type(host_info) ~= "table" or (type(host_info) == "table" and #host_info <= 0)) then
                        break;
                    end
                    local target_node_key = _generate_host_port_key({host=host_info[1], port=host_info[2]})
                    _assigned_cluster_node(target_node_key, settings)
                    if(j == _MASTER_NODE_INDEX+1) then
                        _assigned_slots_node(slot_nums, target_node_key)
                    end
                until true
            end
        until true
    end
end

local function _init_slots_cache(...)
    local settings = {...};
    settings = #settings > 0 and settings[1] or {};
    local host_ports_str = settings.host_ports;

    local cluster_nodes_cache_key = host_ports_str.."nodes";
    local cluster_slots_cache_key = host_ports_str.."slots";
    cluster_nodes = cicache.get(_CLUSTER_CACHE_DICT_KEY, cluster_nodes_cache_key) or {};
    cluster_slots = cicache.get(_CLUSTER_CACHE_DICT_KEY, cluster_slots_cache_key) or citable.new_tab(0, _MAX_SLOT_NUM);
    if citable.is_not_empty(cluster_nodes) and citable.is_not_empty(cluster_slots) then
        return
    end

    local host_ports = _generate_host_ports(host_ports_str);
    for i = 1, #host_ports do
        settings.host = host_ports[i].host;
        settings.port = host_ports[i].port;
        local redis = ciredis:new(settings);
        _discover_nodes_slots(redis, settings)
    end

    cicache.set(_CLUSTER_CACHE_DICT_KEY, cluster_nodes_cache_key, cluster_nodes)
    cicache.set(_CLUSTER_CACHE_DICT_KEY, cluster_slots_cache_key, cluster_slots)
end

function _M.new(self, ... )    
    local settings = {...};
    settings = #settings > 0 and settings[1] or {};
    local timeout = settings.timeout or 3000
    local max_idle_time = settings.max_idle_time or 60000;
    local pool_size = settings.pool_size or 1000
    local host_ports = settings.host_ports;
    --local password = settings.password;
    --local db_index = settings.db_index or 0;

    _init_slots_cache({timeout = timeout, max_idle_time = max_idle_time, pool_size = pool_size, host_ports = host_ports, _reqs = nil});

    return setmetatable({timeout = timeout, max_idle_time = max_idle_time, pool_size = pool_size, host_ports = host_ports, _reqs = nil}, mt)
end

local function _do_command(self, cmd, ...)
    if self._reqs then
        table.insert(self._reqs, {cmd, ...})
        return
    end
    local settings = {...}
    local key = #settings > 0 and settings[1] or "";
    local slot = _key_slot(key);
    local redis_settings = cluster_slots[slot+1];
    local redis = ciredis:new(redis_settings);
    local fun = redis[cmd]
    local result, err = fun(redis, ...)
    if err then
        if(string.sub(err, 1, 5) == "MOVED") then
            _renew_slots_cache(redis);
            return _do_command(self, cmd, ...)
        end
        return nil, err
    end

    if cistring.is_null(result) then
        result = nil
    end
    
    return result, err
end

for i = 1, #commands do
    local cmd = commands[i]
    _M[cmd] = function (self, ...)
        return _do_command(self, cmd, ...)
    end
end


function _M.init_pipeline(self, n)
    self._reqs = citable.new_tab(n or 4, 0)
end

function _M.cancel_pipeline(self)
    self._reqs = nil
end

function _M.commit_pipeline(self)
    local reqs = self._reqs
    if not reqs or 0 == #reqs then
        return nil, "no pipeline"
    end

    self._reqs = nil

    local commands, commands_index, redis_index = {}, {}, {};
    for i = 1, #reqs do
        local cmd = reqs[i]
        local key = cmd and type(cmd) == 'table' and #cmd > 1 and cmd[2] or ""
        local slot = _key_slot(key);
        local redis_settings = cluster_slots[slot+1];
        local redis_settings_index = citable.index_of_key(redis_index, redis_settings)
        if redis_settings_index == nil then
            table.insert(redis_index, redis_settings)
            redis_settings_index = citable.index_of_key(redis_index, redis_settings)
        end
        commands[redis_settings_index] = commands[redis_settings_index] or {}
        table.insert(commands[redis_settings_index], cmd)
        commands_index[redis_settings_index] = commands_index[redis_settings_index] or {}
        table.insert(commands_index[redis_settings_index], i)
    end

    local results = citable.new_tab(0, #reqs)
    local result_hash = citable.new_tab(0, #reqs)
    local index = 1;
    for k, v in pairs(commands) do
        local redis = ciredis:new(redis_index[k]);
        redis:charge_pipeline(v)
        local result, err = redis:commit_pipeline()
        if err then
            return nil, err
        end
        result_hash[index] = citable.assemble(commands_index[k], result)
        index = index + 1
    end
    results = citable.merges(results, result_hash)
    return results, nil
end


return _M