


-- local redis_iresty = require "redis_iresty"
local redis = require "resty.redis"
local cjson_safe = require "cjson.safe"


local config_dict = ngx.shared.config_dict
local redis_mod = cjson_safe.decode(config_dict:get("redis_Mod"))


local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end


local _action = get_argByName("action")
local _key = get_argByName("key")
local _value = get_argByName("value")

local red = redis:new()
red:set_timeout(1000) -- 1 sec

local ok, err = red:connect(redis_mod.ip, redis_mod.Port)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

-- 请注意这里 auth 的调用过程
local count ,err , ok
count, err = red:get_reused_times()
if 0 == count then
    ok, err = red:auth(redis_mod.Password)
    if not ok then
        ngx.say("failed to auth: ", err)
        return
    end
elseif err then
    ngx.say("failed to get reused times: ", err)
    return
end

if _action == "set" then
	ok, err = red:set(_key, _value)
	if not ok then
	    ngx.say("failed to set dog: ", err)
	    return
	end

	ngx.say("set result: ", ok)

elseif _action == "get" then
	local res, err = red:get(_key)
    if not res then
        ngx.say("failed to get "..tostring(_key)..": ", err)
        return
    end

    if res == ngx.null then
        ngx.say("key not found.")
        return
    end

    if _key == "config_dict" or _key == "count_dict" then
        res = cjson_safe.decode(res)
    end
    sayHtml_ext(res)    
elseif _action == "save" then
    if _key == "config_dict" then  --保存dict中的config_dict到redis
        local tmpdict = config_dict
        local _tb,tb_all = tmpdict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            tb_all[v] = tmpdict:get(v)
        end
        local json_config = cjson_safe.encode(tb_all)
        ok, err = red:set("config_dict", json_config)
        if not ok then
            ngx.say("failed to set config_dict: ", err)
            return
        end
        ngx.say("set config_dict result: ", ok)
    elseif _key == "count_dict" then -- 保存dict中的count_dict到redis
        local tmpdict = ngx.shared.count_dict
        local _tb,tb_all = tmpdict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            tb_all[v] = tmpdict:get(v)
        end
        local json_count = cjson_safe.encode(tb_all)
        ok, err = red:set("count_dict", json_count)
        if not ok then
            ngx.say("failed to set count_dict: ", err)
            return
        end
        ngx.say("set count_dict result: ", ok)
    else    
    end
else

end

-- 连接池大小是100个，并且设置最大的空闲时间是 10 秒
local ok, err = red:set_keepalive(10000, 100)
if not ok then
    ngx.say("failed to set keepalive: ", err)
    return
end