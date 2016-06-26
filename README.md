生产部署：
1、将源码发布到/data/lua目录下
2、将源码目录下profiles/pro/nginx_conf/nginx.conf复制到/usr/local/openresty/nginx/conf/nginx.conf
(避开每次启动nginx需要指定配置文件，尽量第一次启动的复制，后续按需复制)
3、在/data/目录下创建nginxlog目录
3、启动nginx。


目录api，存放目标业务代码。
目录ciresty，存放自定义组件。
目录commons，存放公用lua脚本（nginx执行过程）。
目录resty，存放第三方开源组件
目录profiles，存放不同环境配置。

lua-releng为lua脚本全局变量检测工具。

future:
1、封装redis，不需要显示释放链接
2、实现redis-cluster
3、实现兼容版本，不动核心逻辑
4、接口白名单、黑名单，访问频率限制等
5、post请求和get请求参数合并，业务接口普通参数统一从get中获取（上传文件等还是从postBody中）
6、接口访问pv、uv统计
7、json包支持过滤指定fields