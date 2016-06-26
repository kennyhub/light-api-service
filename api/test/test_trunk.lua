local cidate = require "ciresty.date"
local start = cidate.current_millisecond(ngx)
local outputstr = '[{"a":1,"b":2,"c":3},{"a":1,"b":2,"d":3,"f":[],"g":{}}]';
--local responsestr = '{"a":1,"b":2,"c":3}';
-- local outputstr = '{}';
local citable = require 'ciresty.table';
local cjson = require 'ciresty.cjson';
-- local cjson = require 'cjson.safe';
-- local output = cjson.decode(outputstr);
--output = cjson.empty_array;
-- output[1].f = cjson.null;
-- outputstr = cjson.encode(output);
--cjson.encode_empty_table_as_object(true)
-- outputstr = cjson.encode(output, {fields=ngx.var.arg_fields, empty_table_object=false});
-- ngx.print(outputstr);

local routing = require "profiles.redis_routing"

-- local iredis = require "ciresty.redis"
-- redis = iredis:new(routing.count_limit_routing);

local iredis = require "ciresty.redis.cluster"
redis = iredis:new(routing.cluster_price_routing);

-- local redisReq = require "resty.redis"
-- local redis = redisReq:new();
-- redis:set_timeout(1000)
-- local ok,err = redis:connect("10.185.240.131",6379)


-- redis:set("dog", "an animal")
local ok,err
-- redis:init_pipeline();
-- redis:set("dog", "dog")
-- redis:get("dog")
-- redis:set("animal", "cat")
-- redis:get("animal")
-- local ok,err = redis:commit_pipeline();
-- ngx.print("set result: ", ok)

-- ok,err = redis:pfadd("xfasdasd", "a", "b", "c", "1", "10", "3");
-- ok,err = redis:pfcount("xfasdasd");
-- ngx.say([[{"ok":"]]..tostring(ok)..[[", "err":"]]..tostring(err)..[["}]])

-- redis:set_keepalive(60000, 1000)
-- ok, err = redis:get("abcd")
-- ok, err = redis:lpush("pa", "pppp")
-- ok,err = redis:rpop("pa");
-- ok, err = redis:cluster_keyslot("abcd");
-- local str = "%20%3C"
--str = string.gsub(str, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
-- str = ngx.escape_uri([[(*&)&^+  123!":"<><<]])
--str = ngx.unescape_uri(str)


-- local args = ngx.req.get_uri_args()

-- ngx.print(cjson.encode(args))
-- ngx.say(ngx.today());
-- ngx.say(ngx.time())
-- ngx.say(ngx.now())
-- ngx.say(ngx.update_time())
-- ngx.say( ngx.localtime())
-- ngx.say(ngx.utctime())
-- ngx.say(cjson.encode(ngx.ctx.common_params))

-- local mab = {
-- 	a=1
-- };

redis:set("a1", 1);
redis:set("a2", 2);
redis:set("a6", 6);

redis:init_pipeline();
for i = 1, 6 do
    redis:get('a' .. i)
end
ok,err = redis:commit_pipeline();

ngx.say(cjson.encode(ok, {fields=ngx.var.arg_fields, empty_table_object=false}))

--ngx.log(ngx.ERR, 'content耗时：'..(cidate.current_millisecond(ngx)-start))
-- ngx.ctx.API_SUB_MODULE_BODY_FILTER = {
-- 	"api.test.test_trunk_body_filter1","api.test.test_trunk_body_filter2"
-- }




























