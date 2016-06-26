local outputstr = ngx.ctx['outputstr'];
outputstr = ngx.re.sub(outputstr, '"nil"', '0')
ngx.ctx['outputstr'] = outputstr