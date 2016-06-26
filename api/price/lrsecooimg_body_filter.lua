local _M = {}
_M._VERSION = '0.0.1'

local citable = require 'ciresty.table';
local cistring = require 'ciresty.string';
local cjson = require 'ciresty.cjson';
local cidate = require "ciresty.date";

local function _repair_product_info(inventory_price, products, refer_inventory_price, exclusive_product_qrcode, presale_product)
	if not inventory_price or type(inventory_price) ~= 'table' then
		return 
	end
	local productid = inventory_price.pidStr
	local product_price = products[productid]
	if not product_price then
		return 
	end
	inventory_price.secooPrice = product_price.s and product_price.s.np or inventory_price.secooPrice
	local advert = product_price.a
	if citable.is_not_empty(advert) and advert[1] and advert[1].t == 0 then
		inventory_price.phActName = advert[1].n
		inventory_price.phActStartDate = advert[1].s
		inventory_price.phActEndDate = advert[1].e
		inventory_price.phActPhStartDate = advert[1].as
		inventory_price.phActPrice = advert[1].p
	end
	if citable.is_not_empty(advert) then
		local exclusive_advert = table.remove(advert)
		if exclusive_advert and exclusive_advert.t == 1 then
			inventory_price.activityExclusivePrice = exclusive_advert.p
			inventory_price.activityExclusiveStartDate = exclusive_advert.s
			inventory_price.activityExclusiveEndDate = exclusive_advert.e
			if exclusive_product_qrcode then
				local exclusive_promotion_info_old = cjson.decode(exclusive_product_qrcode[productid]) or {}
				inventory_price.appLinkPicUrl = exclusive_promotion_info_old.appLinkPicUrl
			end
		end
	end
	if refer_inventory_price and type(refer_inventory_price) == 'table' and #refer_inventory_price > 0 then
		inventory_price.totalSize = inventory_price.size
		for i = 1, #refer_inventory_price do
			repeat
				local refer_single_inventory_price = cjson.decode(refer_inventory_price[i])
				if not refer_single_inventory_price or type(refer_single_inventory_price) ~= 'table' then
					break 
				end
				inventory_price.totalSize = inventory_price.totalSize + refer_single_inventory_price.size
			until true
		end
	end
	if presale_product then
		local current_millisecond = cidate.current_millisecond(ngx);
		local presale = cjson.decode(presale_product)
		if presale and presale.startDate <= current_millisecond and presale.endDate >= current_millisecond then
			inventory_price.isNewPresale = 1
			local depositAmount = inventory_price.secooPrice * 0.2;
			inventory_price.preasleDesc = '预定金￥'..depositAmount..' + 尾款￥'..(inventory_price.secooPrice-depositAmount);
			if presale and presale.payPresaleFinalPaymentDate <= presale.endDate and current_millisecond >= presale.payPresaleFinalPaymentDate then
				inventory_price.presaleDeliveryDesc="支付完成后3天内发货";
	            inventory_price.canPayPresaleFinalPayment = 1;
	        else
	            inventory_price.canPayPresaleFinalPayment = 0;
	            inventory_price.presaleDeliveryDesc="尾款支付完成后3天内发货";
	        end
		end

	end
	return inventory_price
end

function _M.executor(outputstr)
	local output = cjson.decode(outputstr)
	if not output or not output.retCode or tonumber(output.retCode) ~= 0 then
		return outputstr
	end
	local products = output.products or {};
	if not products or type(products) ~= 'table' then
		return outputstr
	end
	local refer_inventory_prices = ngx.ctx['refer_inventory_prices'] or {}
	local inventory_prices = ngx.ctx['inventory_prices']
	local exclusive_product_qrcode = ngx.ctx['exclusive_product_qrcode'] or {}
	local presale_products = ngx.ctx['presale_products'] or {}

	if not inventory_prices or type(inventory_prices) ~= 'table' or #inventory_prices == 0 then
		return '[]'
	end

	local output_product = citable.new_tab(0, #inventory_prices)
	for i = 1, #inventory_prices do
		local inventory_price = _repair_product_info(cjson.decode(inventory_prices[i]), products, refer_inventory_prices[i], exclusive_product_qrcode, presale_products[i])
		if inventory_price then
			table.insert(output_product, inventory_price)
		end
	end

	outputstr = cjson.encode(output_product, {fields=ngx.var.arg_fields, empty_table_object=false})
	return outputstr
end

return _M