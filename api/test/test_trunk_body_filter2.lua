local outputstr = ngx.ctx['outputstr'];
outputstr = ngx.re.sub(outputstr, 'null', '')
ngx.ctx['outputstr'] = outputstr