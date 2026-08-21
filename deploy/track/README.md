# 通用访问统计接入指南（tracker.js）

给你的任意项目加上访问统计，只需要**一行 script 标签**。数据由 `harness.zhigouread.com` 上的自托管统计平台采集，每个项目自动生成一套完整看板（PV/UV、地域分布、分时段、每日趋势、热门页面、访客来源、最近访问）。

## 快速接入

在项目的每个 HTML 页面 `<head>` 或 `<body>` 末尾加：

```html
<script defer src="https://harness.zhigouread.com/t/tracker.js" data-site="你的项目名"></script>
```

- `data-site`：**必填**，项目标识。只允许小写字母、数字、连字符（如 `my-blog`、`notes-2026`）。看板地址由它决定：
  `https://harness.zhigouread.com/stats/sites/你的项目名/`
- 全部项目总览：`https://harness.zhigouread.com/stats/sites/`

### 常见项目类型的接入位置

| 项目类型 | 加在哪里 |
|---|---|
| 纯 HTML | 每个页面 `<body>` 末尾；有公共模板/布局文件的话只加一处 |
| VitePress | `.vitepress/config.mts` 的 `head` 数组：`['script', { defer: true, src: 'https://harness.zhigouread.com/t/tracker.js', 'data-site': 'xxx' }]` |
| Vue / React SPA | `index.html` 的 `<head>`（路由切换已内置支持，见下） |
| Next.js | `app/layout.tsx` 或 `_document.js` |
| WordPress | 主题 `footer.php`，或用「Insert Headers and Footers」类插件 |

## 工作原理

```
访客浏览器 ──GET 1像素图片(携带页面路径/来源)──► harness.zhigouread.com/t/hit
                                                    │ Nginx 直接返回 204，请求落入 track.log
                                                    ▼
                              服务器上的统计脚本（每 5 分钟）解析日志、按项目分组
                                                    ▼
                              生成静态看板 /stats/sites/<项目名>/index.html
```

- 上报用的是 `new Image()` 的 GET 请求，**不受 CORS 限制**，任何域名的页面都能接入。
- 无 Cookie、不读 localStorage、不做设备指纹。UV 按「IP + 天」去重。
- 已内置 SPA 支持：`pushState` / `popstate` / `hashchange` 切换路由都会自动上报（同一路径不重复计）。

## 注意事项（重要）

1. **看板是公开的**。知道 URL 的人都能看。`data-site` 不要用包含敏感信息的名字（如内部项目代号）；把它当作「公开昵称」。
2. **广告拦截器会漏计**。部分访客的浏览器插件会拦截统计脚本（经验值 10%~30%）。这是前端埋点的固有特性——主站那套基于 Nginx 日志的统计不受此影响，两套口径不要直接对比数字。
3. **自己的访问也会被统计**。目前不按 IP 排除任何人（包括你自己）。看趋势时心里有数即可；早期数据基本都是你自己。
4. **爬虫/扫描已自动过滤**（UA 含 bot/curl/scanner 等特征的单独计数，不计入 PV/UV），但伪装成浏览器的扫描器仍会漏进来，属于正常现象。
5. **地域精度**：免费 GeoIP（ip-api.com），中国境内到省/城市是运营商级近似；手机流量常定位到省会城市。
6. **没有防刷机制**。采集端点无鉴权，任何人构造请求都能写入数据。适合个人站点看趋势，不适合对外承诺数据的正式场景。
7. **多项目互不影响**。每个 `data-site` 独立统计、独立看板；同一个域名下的多个路径如需区分，建议拆成不同 `data-site`。
8. **文件覆盖**。看板目录在服务器上是独立路径（`C:\web\stats\sites\`），重新发布主站或其他项目都不会影响统计数据。
9. **data-endpoint 可自定义**。如果你把这套东西整体搬到自己的服务器，把端点换成自己的：
   `<script defer src="https://你的域名/t/tracker.js" data-site="xxx" data-endpoint="https://你的域名/t/hit"></script>`

## 这套系统由什么组成（想搬到自己的服务器时参考）

| 文件 | 作用 |
|---|---|
| `deploy/track/tracker.js` | 埋点脚本，部署到 Nginx 的 `/t/tracker.js` |
| `deploy/track/Update-TrackStats.ps1` | 日志分析 + 看板生成，Windows 计划任务每 5 分钟执行 |
| `deploy/nginx.conf` 中的 `/t/hit`、`/t/tracker.js` 两个 location | 采集端点与脚本托管 |
| 服务器 `C:\stats\geo-cache.json` | GeoIP 缓存（每个 IP 只查一次） |

整体架构零后端代码：采集 = Nginx 日志，分析 = PowerShell 定时任务，展示 = 静态 HTML。
