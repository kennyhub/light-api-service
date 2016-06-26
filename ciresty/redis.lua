local redis_c = require "resty.redis"
local citable = require "ciresty.table"
local cistring = require "ciresty.string"

local _M = citable.new_tab(0, 155)
_M._VERSION = '0.0.1'

local mt = { __index = _M }

local commands = {
    "append",            "auth",              "bgrewriteaof",
    "bgsave",            "bitcount",          "bitop",
    "blpop",             "brpop",
    "brpoplpush",        "client",            "config",
    "dbsize",
    "debug",             "decr",              "decrby",
    "del",               "discard",           "dump",
    "echo",
    "eval",              "exec",              "exists",
    "expire",            "expireat",          "flushall",
    "flushdb",           "get",               "getbit",
    "getrange",          "getset",            "hdel",
    "hexists",           "hget",              "hgetall",
    "hincrby",           "hincrbyfloat",      "hkeys",
    "hlen",
    "hmget",             "hmset",            "hscan",
    "hset",
    "hsetnx",            "hvals",             "incr",
    "incrby",            "incrbyfloat",       "info",
    "keys",
    "lastsave",          "lindex",            "linsert",
    "llen",              "lpop",              "lpush",
    "lpushx",            "lrange",            "lrem",
    "lset",              "ltrim",             "mget",
    "migrate",
    "monitor",           "move",              "mset",
    "msetnx",            "multi",             "object",
    "persist",           "pexpire",           "pexpireat",
    "ping",              "psetex",         --[[ "psubscribe",]]
    "pttl",
    "publish",      --[[ "punsubscribe", ]]   "pubsub",
    "quit",
    "randomkey",         "rename",            "renamenx",
    "restore",
    "rpop",              "rpoplpush",         "rpush",
    "rpushx",            "sadd",              "save",
    "scan",              "scard",             "script",
    "sdiff",             "sdiffstore",
    "select",            "set",               "setbit",
    "setex",             "setnx",             "setrange",
    "shutdown",          "sinter",            "sinterstore",
    "sismember",         "slaveof",           "slowlog",
    "smembers",          "smove",             "sort",
    "spop",              "srandmember",       "srem",
    "sscan",
    "strlen",       --[[ "subscribe", ]]      "sunion",
    "sunionstore",       "sync",              "time",
    "ttl",
    "type",         --[[ "unsubscribe", ]]    "unwatch",
    "watch",             "zadd",              "zcard",
    "zcount",            "zincrby",           "zinterstore",
    "zrange",            "zrangebyscore",     "zrank",
    "zrem",              "zremrangebyrank",   "zremrangebyscore",
    "zrevrange",         "zrevrangebyscore",  "zrevrank",
    "zscan",
    "zscore",            "zunionstore",       "evalsha"
}

local sub_commands = {
    "subscribe", "psubscribe"
}


local unsub_commands = {
    "unsubscribe", "punsubscribe"
}

local function connect(self, redis)    
    redis:set_timeout(self.timeout)
    local ok,err = redis:connect(self.host, self.port)
    if self.password and ok then
        ok, err = redis:auth(self.password)
    end 
    return ok,err
end

function _M.new(self, ... )    
    local settings = {...};
    settings = #settings > 0 and settings[1] or {};
    local timeout = settings.timeout or 3000
    local db_index = settings.db_index or 0;
    local max_idle_time = settings.max_idle_time or 60000;
    local pool_size = settings.pool_size or 1000
    local host = settings.host;
    local port = settings.port;
    local password = settings.password;

    return setmetatable({db_index = db_index, timeout = timeout, max_idle_time = max_idle_time, pool_size = pool_size, host = host, port = port, password = password, _reqs = nil}, mt)
end

function _M.set_keepalive(self, redis)
    return redis:set_keepalive(self.max_idle_time, self.pool_size) 
end

local function _do_command(self, cmd, ...)
    if self._reqs then
        table.insert(self._reqs, {cmd, ...})
        return
    end

    -- local settings = {cmd, ...}
    --     for i = 1, #settings do
    --     ngx.log(ngx.ERR, "key: "..type(settings[i]).."--"..settings[i])
    -- end

    local redis, err = redis_c:new()
    if not redis then
        return nil, err
    end

    local ok, err = connect(self, redis)
    if not ok or err then
        return nil, err
    end

    local fun = redis[cmd]
    local result, err = fun(redis, ...)
    if not result or err then
        return nil, err
    end

    if cistring.is_null(result) then
        result = nil
    end
    
    self:set_keepalive(redis)

    return result, err
end

function _M.init_pipeline(self, n)
    self._reqs = citable.new_tab(n or 4, 0)
end

function _M.cancel_pipeline(self)
    self._reqs = nil
end

function _M.charge_pipeline(self, commands)
    self:init_pipeline();
    if not commands or type(commands) ~= 'table' then
        return
    end
    self._reqs = commands
end

function _M.commit_pipeline(self)
    local reqs = self._reqs
    if not reqs or 0 == #reqs then
        return nil, "no pipeline"
    end

    self._reqs = nil

    local redis, err = redis_c:new()
    if not redis then
        return redis, err
    end

    local ok, err = connect(self, redis)
    if not ok then
        return ok, err
    end

    redis:init_pipeline()

    for _, vals in ipairs(reqs) do
        local fun = redis[vals[1]]
        table.remove(vals , 1)
        fun(redis, unpack(vals))
    end
    
    local results, err = redis:commit_pipeline()
    if not results or err then
        return results, err
    end
    if cistring.is_null(results) then
        results = {}
    end
    
    self:set_keepalive(redis)

    for i,value in ipairs(results) do
        if cistring.is_null(value) then
            results[i] = nil
        end
    end

    return results, err
end


for i = 1, #commands do
    local cmd = commands[i]
    _M[cmd] = function (self, ...)
        return _do_command(self, cmd, ...)
    end
end

for i = 1, #sub_commands do
    local cmd = sub_commands[i]
    _M[cmd] = function (self, ...)
        self.subscribed = true
        return _do_command(self, cmd, ...)
    end
end

for i = 1, #unsub_commands do
    local cmd = unsub_commands[i]
    _M[cmd] = function (self, ...)
        local res, err = _do_command(self, cmd, ...)
        _check_subscribed(self, res)
        return res, err
    end
end

function _M.subscribe( self, channel )
    local redis, err = redis_c:new()
    if not redis then
        return nil, err
    end

    local ok, err = connect(self, redis)
    if not ok or err then
        return nil, err
    end

    local res, err = redis:subscribe(channel)
    if not res then
        return nil, err
    end

    res, err = redis:read_reply()
    if not res then
        return nil, err
    end

    redis:unsubscribe(channel)
    self:set_keepalive(redis)

    return res, err
end

local cluster_sub_commands = {
    "addslots",
    "count-failure-reports",
    "countkeysinslot",
    "delslots",
    "failover",
    "forget",
    "getkeysinslot",
    "info",
    "keyslot",
    "meet",
    "nodes",
    "replicate",
    "reset",
    "saveconfig",
    "set-config-epoch",
    "setslot",
    "slaves",
    "slots"
}

local cluster_commands = {
    -- "readonly",
    -- "readwrite"
}

for i = 1, #cluster_commands do
    local cmd = cluster_commands[i]
    redis_c.add_commands(cmd);
    _M[cmd] = function (self, ...)
        return _do_command(self, cmd, ...)
    end
end

for i = 1, #cluster_sub_commands do
    local cmd = "cluster_"..cluster_sub_commands[i]
    redis_c.add_sub_commands("cluster", cluster_sub_commands[i]);
    _M[cmd] = function (self, ...)
        return _do_command(self, cmd, ...)
    end
end

local geo_commands = {
    "geoadd",
    "geohash",
    "geopos",
    "geodist",
    "georadius",
    "georadiusbymember"
}

for i = 1, #geo_commands do
    local cmd = geo_commands[i]
    redis_c.add_commands(cmd);
    _M[cmd] = function (self, ...)
        return _do_command(self, cmd, ...)
    end
end


local hyper_log_log_commands = {
    "pfadd",
    "pfcount",
    "pfmerge"
}

for i = 1, #hyper_log_log_commands do
    local cmd = hyper_log_log_commands[i]
    redis_c.add_commands(cmd);
    _M[cmd] = function (self, ...)
        return _do_command(self, cmd, ...)
    end
end

return _M