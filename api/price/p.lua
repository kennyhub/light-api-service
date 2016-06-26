local citable = require 'ciresty.table';
local cistring = require 'ciresty.string';
local cihttp = require 'ciresty.http';
local cjson = require 'ciresty.cjson';
local cidate = require "ciresty.date"
local ciredis = require "ciresty.redis"
local ciredis_cluster = require "ciresty.redis.cluster"

local productidstrs = ngx.var.arg_productids
local fields = ngx.var.arg_fields
local output = {}

if cistring.is_blank(productidstrs) or not ngx.re.find(tostring(productidstrs), '^(?:,?[0-9]+)+,?$') then
	output.retCode = 1
	output.retMsg = "参数productids非法"
	ngx.print(cjson.encode(output, fields, 0, false))
	return ;
end

local promotion_type = {
	fixed_price = "0",
	exclusive_price = "1",
	fixed_settle_price = "2"
}

local rds_key = {
	secoo_price_prefix = 'com.secoo.prices.front.secooPrice.productId_',
	settle_price_prefix = 'com.secoo.prices.front.settlementPrice.productId_',
	product_promotions_prefix = 'com.secoo.prices.front.promotionPrice.productId_',
	exchange_rate = 'com.secoo.prices.front.exchangeRate_'
}

local function _batch_rds(redis, rds_key_prefix, productids)
	if not productids or #productids == 0 then 
		return {}
	end
	redis:init_pipeline();
	for i = 1, #productids do
	    redis:get(rds_key_prefix .. productids[i])
	end
	return redis:commit_pipeline() or {};
end

local function _batch_products(redis, rds_key_prefix, productids)
	local res, err = _batch_rds(redis, rds_key_prefix, productids)
	if err then
		return {}
	end
	local products = citable.new_tab(0, #productids)
	for i = 1, #productids do
		products[productids[i]] = res[i]
	end
	return products;
end

local function _channel_id(channels)
	local channel = 10
	local sub_channel = -1
	local platform_type = channels.platform_type
	if platform_type >= 0 then
		channel = 60;
	end
	if platform_type == 0 then
		sub_channel = 1
	elseif platform_type == 1 then
		sub_channel = 2
	elseif platform_type == 2 then
		sub_channel = -1
	elseif platform_type == 3 then
		sub_channel = 3
	elseif platform_type == 4 then
		sub_channel = 4
	elseif platform_type == 5 then
		sub_channel = 5
	end
	return {channel=channel, sub_channel=sub_channel}
end

local function _currency_id(channels)
	return "0";
end

local function _promotion_channel_match(channels, promotion_channels)
	local channel, sub_channel = channels.channel, channels.sub_channel;
	if not promotion_channels or type(promotion_channels) ~= 'table' then
		return true;
	end
	for i = 1, #promotion_channels do
		local promotion_channel = promotion_channels[i]
		if promotion_channel.channelId == tostring(channel) then
			if sub_channel == -1 then
				return true;
			end
			local sub_channel_ids = promotion_channel.secondChannelId
			if not sub_channel_ids then
				return true;
			end
			if citable.contains_value(sub_channel_ids, tostring(sub_channel)) then
				return true;
			end
		end
	end
	return false;
end

local function _batch_secoo_price_by_channel(redis, rds_key_prefix, productids, channels)
	local products = _batch_products(redis, rds_key_prefix, productids)
	local secoo_prices = citable.new_tab(0, #products)
	local product_other_prices = citable.new_tab(0, #products)
	for key, val in pairs(products) do
		repeat
        	local secoo_price_tab = cjson.decode(val);
        	if not secoo_price_tab or type(secoo_price_tab) ~= 'table' then
        		break
        	end
        	for i = 1, #secoo_price_tab do
				local secoo_price_obj = secoo_price_tab[i];
				if(secoo_price_obj and secoo_price_obj['currencyId'] and secoo_price_obj['currencyId'] == _currency_id(channels)) then
					secoo_prices[key] = tonumber(secoo_price_obj['secooPrice'])
					local ruleValue = secoo_price_obj['ruleValue'];
					if ruleValue then
						ruleValue = cjson.decode(ruleValue)
						product_other_prices[key] = {
							carriage = ruleValue and ruleValue['carriage'] or 0,
							tariff = ruleValue and ruleValue['tariff'] or 0
						}
					end
					break;
				end
			end
        until true
    end
    return secoo_prices, product_other_prices
end

local function _cacl_promotion_rule(orign_price, rule_id, rule_values)
	if not rule_id or not rule_values then
		return orign_price
	end
	local target_price = orign_price;
	local rule_value = tonumber(rule_values['x'..rule_id]);
	if rule_id == "0" then
		target_price = rule_value
	elseif rule_id == "1" then
		target_price = orign_price + rule_value
	elseif rule_id == "2" then
		target_price = orign_price - rule_value
	elseif rule_id == "3" then
		target_price = orign_price * rule_value
	end
	return target_price;
end

local function _cacl_product_price(params)
	local secoo_price, advert_price = {}, nil
	local productid = params.productid
	local product_secoo_price = params.product_secoo_price
	local other_price = params.product_other_price
	local product_promotions = params.product_promotion_tab
	local channels = params.channels;
	local is_join_exclusive = false;

	secoo_price.sp = product_secoo_price;
	secoo_price.np = product_secoo_price

	if not product_promotions or type(product_promotions) ~= 'table' then
		return {
	    	s = secoo_price,
	    	a = advert_price,
	    	o = other_price,
	    	currency = tonumber(_currency_id())
		}, is_join_exclusive	
	end
	local current_millisecond = cidate.current_millisecond(ngx);
	table.sort(product_promotions, function(a,b)
		return a.promotionPricePriority < b.promotionPricePriority
	end)
	for i = 1, #product_promotions do
		repeat
			local product_promotion = product_promotions[i] or {};
			if not product_promotion or product_promotion['promotionType'] == promotion_type.fixed_settle_price  then
				break;
			end
			local promotion_info = product_promotion.promotionInfo;
			local advert_start_time = cidate.parse(promotion_info['advertisingStartTime'])
			local advert_end_time = cidate.parse(promotion_info['advertisingEndTime'])
			local promotion_start_time = cidate.parse(product_promotion['startTime'])
			local promotion_end_time = cidate.parse(product_promotion['endTime'])
			local is_join_advertis, is_join_promotion = false, false
			if not _promotion_channel_match(channels, product_promotion.promotionCondition.channel) then
				if channels and channels.channel == 10 and product_promotion['promotionType'] == promotion_type.exclusive_price then
					is_join_exclusive = true;
					advert_price = advert_price or {};
					table.insert(advert_price, {n=product_promotion['promotionName'], p=_cacl_promotion_rule(secoo_price.np, product_promotion['ruleId'], product_promotion['ruleValue']), as=promotion_start_time, s=promotion_start_time, e=promotion_end_time, t=tonumber(product_promotion['promotionType'])})
				end
				break;
			end
			repeat
				if promotion_info.isAdvertising ~= "1" then
					break;
				end
				if(current_millisecond < advert_start_time or current_millisecond > advert_end_time) then
					break;
				end
				is_join_advertis = true;
			until true
			repeat
				if(current_millisecond < promotion_start_time or current_millisecond > promotion_end_time) then
					break;
				end
				secoo_price.np = _cacl_promotion_rule(secoo_price.np, product_promotion['ruleId'], product_promotion['ruleValue']);
				is_join_promotion = true;
			until true
			if is_join_advertis then
				advert_price = advert_price or {};
				table.insert(advert_price, {n=promotion_info['advertisingName'], p=tonumber(product_promotion['promotionPrice']), as=advert_start_time, s=promotion_start_time, e=promotion_end_time, t=tonumber(product_promotion['promotionType'])})
			end
			if is_join_promotion then
				local pps = {p=secoo_price.np, i=tonumber(product_promotion['promotionId']), s=promotion_start_time, e=promotion_end_time, n=product_promotion['promotionName'], t=tonumber(product_promotion['promotionType'])}
				secoo_price.pps = secoo_price.pps or {}
				table.insert(secoo_price.pps, pps)
			end
		until true
	end
    return {
    	s = secoo_price,
    	a = advert_price,
    	o = other_price,
    	currency = tonumber(_currency_id())
	}, is_join_exclusive
end

local productids = cistring.split(productidstrs, ',', true)

local common_params = ngx.ctx.common_params or {}
local routing = require "profiles.redis_routing"
--local redis = ciredis:new(routing.price_routing)
local redis = ciredis_cluster:new(routing.cluster_price_routing)

local channels = _channel_id({platform_type=common_params.platform_type});
--local product_secoo_prices = _batch_products(redis, rds_key.secoo_price_prefix, productids)
local product_secoo_prices, product_other_prices = _batch_secoo_price_by_channel(redis, rds_key['secoo_price_prefix'], productids, channels)
local product_promotions = _batch_products(redis, rds_key['product_promotions_prefix'], productids)

local products_result = citable.new_tab(0, #productids)
local join_exclusive_productids = citable.new_tab(0, #productids)
for i = 1, #productids do
	local productid = productids[i]
	local product_secoo_price = product_secoo_prices[productid]
	local product_other_price = product_other_prices[productid]
	local product_promotion_tab = cjson.decode(product_promotions[productid]);
	local is_join_exclusive = false;

	products_result[tostring(productid)], is_join_exclusive = _cacl_product_price({
		productid = productid,
		product_secoo_price = product_secoo_price, 
		product_promotion_tab = product_promotion_tab,
		product_other_price = product_other_price,
		channels = channels
	})

	if is_join_exclusive then
		table.insert(join_exclusive_productids, productid)
	end
end
output = {
	retCode = 0,
	retMsg = 'successful',
	products = products_result
}
--------------- 老版本兼容 数据获取 ------------------
local version = common_params.version
ngx.ctx.API_SUB_MODULE_BODY_FILTER = ngx.ctx.API_SUB_MODULE_BODY_FILTER or {}
if version and version == '0.8' then
	ngx.print(cjson.encode(output, {empty_table_object=true}))
	local redis_product = ciredis:new(routing.product_routing)
	local inventory_prices = _batch_rds(redis_product, '/itemCache_', productids)
	ngx.ctx.inventory_prices = inventory_prices

	local redis_exclusive = ciredis:new(routing.activity_exclusive_routing)
	if join_exclusive_productids and #join_exclusive_productids > 0 then
		local exclusive_product_qrcode = _batch_rds(redis_exclusive, 'activity_exclusive_', join_exclusive_productids)
		ngx.ctx.exclusive_product_qrcode = citable.assemble(join_exclusive_productids, exclusive_product_qrcode)
	end

	local presale_products = _batch_rds(redis_exclusive, 'presale_2016707_', productids)
	ngx.ctx.presale_products = presale_products

	local is_multi_spec = ngx.var.arg_is_multi_spec
	if is_multi_spec ~= nil and tostring(is_multi_spec) == '1' then
		local redis_scm = ciredis:new(routing.scm_routing)
		local refer_productidstrs = _batch_rds(redis_scm, 'refProductId_', productids)
		local refer_productids = citable.new_tab(0, #productids)
		local refer_all_productids = citable.new_tab(0, #productids)
		for i = 1, #refer_productidstrs do
			local curr_refer_productids = refer_productidstrs[i] and cistring.split(refer_productidstrs[i], ',', true) or {};
			refer_all_productids = citable.add_all(refer_all_productids, curr_refer_productids)
			refer_productids[i] = curr_refer_productids
		end
		local refer_inventory_prices_hash = citable.assemble(refer_all_productids, _batch_rds(redis_product, '/itemCache_', refer_all_productids))
		for i = 1, #refer_productids do
			local refer_productid = refer_productids[i]
			if refer_productid and type(refer_productid) == 'table' and #refer_productid > 0 then
				for j = 1, #refer_productid do
					refer_productid[j] = refer_inventory_prices_hash[refer_productid[j]]
				end
				refer_productids[i] = refer_productid
			end
		end
		ngx.ctx.refer_inventory_prices = refer_productids
	end
	table.insert(ngx.ctx.API_SUB_MODULE_BODY_FILTER, 'api.price.lrsecooimg_body_filter')
else
	ngx.print(cjson.encode(output, {fields=fields, empty_table_object=true}))
end
