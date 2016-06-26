local cihttp = require("ciresty.http")

cihttp.merge_params(ngx)
ngx.ctx.common_params = cihttp.common_params(ngx)
