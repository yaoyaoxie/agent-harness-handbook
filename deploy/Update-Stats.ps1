# Update-Stats.ps1 — 解析 Nginx access.log，生成网站访问统计页
# 每小时由计划任务调用，也可手动执行：powershell -ExecutionPolicy Bypass -File C:\stats\Update-Stats.ps1

$logPath = "C:\nginx\logs\access.log"
$outDir  = "C:\web\stats"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (-not (Test-Path $logPath)) {
    "no log" | Out-File "$outDir\index.html" -Encoding utf8
    exit 0
}

# access.log 格式（nginx main）：
# IP - - [21/Aug/2026:16:43:34 +0800] "GET /path HTTP/1.1" 200 1234 "referer" "UA"
$pattern = '^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) [^"]*" (\d{3}) (\S+) "([^"]*)" "([^"]*)"'

$daily   = @{}   # 日期 -> @{ Req; PV; IPs }
$allIPs  = @{}   # 全站累计去重 IP（仅页面访问）
$topPages = @{}  # 路径 -> PV
$totalReq = 0
$botReq   = 0

Get-Content $logPath | ForEach-Object {
    if ($_ -match $pattern) {
        $ip     = $Matches[1]
        $day    = $Matches[2].Substring(0, 11)   # 21/Aug/2026
        $method = $Matches[3]
        $uri    = $Matches[4]
        $status = $Matches[5]
        $ua     = $Matches[8]

        if (-not $daily.ContainsKey($day)) {
            $daily[$day] = @{ Req = 0; PV = 0; IPs = @{} }
        }
        $daily[$day].Req++
        $totalReq++

        $isBot = ($ua -match '(?i)bot|spider|crawler|slurp|bingpreview|headless|scrapy|python-requests|curl')
        if ($isBot) { $botReq++; return }

        # 页面访问（PV）判定：GET + 200 + 不是静态资源/接口文件
        $isPage = ($method -eq "GET") -and ($status -eq "200") -and `
                  ($uri -notmatch '\.(js|css|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|map|xml|txt|json|zip|webmanifest|pdf)(\?|$)') -and `
                  ($uri -notlike '/assets/*')
        if ($isPage) {
            $daily[$day].PV++
            $daily[$day].IPs[$ip] = $true
            $allIPs[$ip] = $true
            $path = ($uri -split '\?')[0]
            if (-not $topPages.ContainsKey($path)) { $topPages[$path] = 0 }
            $topPages[$path]++
        }
    }
}

# 按真实日期排序（dd/MMM/yyyy -> datetime）
$culture = [Globalization.CultureInfo]::InvariantCulture
$months  = @{ Jan=1; Feb=2; Mar=3; Apr=4; May=5; Jun=6; Jul=7; Aug=8; Sep=9; Oct=10; Nov=11; Dec=12 }
function DayKey($d) {  # "21/Aug/2026" -> "2026-08-21"
    $p = $d -split '/'
    '{0}-{1:D2}-{2:D2}' -f [int]$p[2], $months[$p[1]], [int]$p[0]
}

$todayKey = (Get-Date).ToString('yyyy-MM-dd')
$todayPV = 0; $todayUV = 0
$rows = New-Object System.Collections.Generic.List[string]
$totalPV = 0

$sortedDays = $daily.Keys | Sort-Object { DayKey $_ }
$maxPV = 1
foreach ($d in $sortedDays) { if ($daily[$d].PV -gt $maxPV) { $maxPV = $daily[$d].PV } }

foreach ($d in $sortedDays) {
    $key = DayKey $d
    $pv  = $daily[$d].PV
    $uv  = $daily[$d].IPs.Count
    $req = $daily[$d].Req
    $totalPV += $pv
    if ($key -eq $todayKey) { $todayPV = $pv; $todayUV = $uv }
    $barWidth = [math]::Round(($pv / $maxPV) * 100)
    $rows.Add(("<tr><td>{0}</td><td class='num'>{1}</td><td class='num'>{2}</td><td class='num'>{3}</td><td class='barcell'><div class='bar' style='width:{4}%'></div></td></tr>" -f $key, $pv, $uv, $req, $barWidth))
}
$rows.Reverse()  # 最近日期在前

# 近 30 天小计
$recent = $sortedDays | Select-Object -Last 30
$pv30 = 0; foreach ($d in $recent) { $pv30 += $daily[$d].PV }

# 热门页面 Top 10
$pageRows = New-Object System.Collections.Generic.List[string]
$i = 0
foreach ($kv in ($topPages.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
    $i++
    $pageRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
}

$generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>访问统计 · Agent Harness 手册</title>
<style>
  body { font-family: -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif; margin: 0; background: #f6f7f9; color: #2c3e50; }
  .wrap { max-width: 860px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .sub { color: #8a94a6; font-size: 13px; margin-bottom: 24px; }
  .cards { display: flex; gap: 14px; flex-wrap: wrap; margin-bottom: 28px; }
  .card { background: #fff; border-radius: 10px; padding: 18px 22px; flex: 1; min-width: 150px; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  .card .label { font-size: 13px; color: #8a94a6; }
  .card .value { font-size: 30px; font-weight: 700; margin-top: 6px; }
  .card .value em { font-size: 13px; font-style: normal; color: #8a94a6; font-weight: 400; }
  h2 { font-size: 16px; margin: 28px 0 12px; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  th, td { padding: 9px 14px; font-size: 13px; text-align: left; }
  th { background: #f0f2f5; color: #5a6472; font-weight: 600; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  tr + tr td { border-top: 1px solid #f0f2f5; }
  .barcell { width: 30%; }
  .bar { height: 10px; background: #4a7ddb; border-radius: 5px; min-width: 1px; }
  .path { font-family: ui-monospace, monospace; font-size: 12px; }
  .note { color: #8a94a6; font-size: 12px; margin-top: 20px; line-height: 1.8; }
</style>
</head>
<body>
<div class="wrap">
  <h1>访问统计 · Agent Harness 手册</h1>
  <div class="sub">数据来源：服务器 Nginx 访问日志 · 每小时更新 · 生成于 $generatedAt</div>
  <div class="cards">
    <div class="card"><div class="label">今日页面浏览量（PV）</div><div class="value">$todayPV</div></div>
    <div class="card"><div class="label">今日访客数（UV）</div><div class="value">$todayUV</div></div>
    <div class="card"><div class="label">近 30 天 PV</div><div class="value">$pv30</div></div>
    <div class="card"><div class="label">累计 PV <em>/ 累计访客</em></div><div class="value">$totalPV <em>/ $($allIPs.Count)</em></div></div>
  </div>
  <h2>每日趋势</h2>
  <table>
    <tr><th>日期</th><th class="num">PV</th><th class="num">UV</th><th class="num">总请求</th><th></th></tr>
    $($rows -join "`n")
  </table>
  <h2>热门页面 Top 10</h2>
  <table>
    <tr><th class="num">#</th><th>页面</th><th class="num">PV</th></tr>
    $($pageRows -join "`n")
  </table>
  <div class="note">
    PV = 页面浏览量（仅统计网页文档，不含 JS/CSS/图片等静态资源）；UV = 独立访客数（按 IP 去重，同一网络出口的多人会计为 1）；总请求 = 含静态资源的全部请求。<br>
    已过滤常见爬虫/机器流量（UA 含 bot/spider/crawler 等，共 $botReq 次）。统计口径比前端埋点（如百度统计）略宽，比 CDN 日志略窄，用于观察趋势足够准确。
  </div>
</div>
</body>
</html>
"@

$html | Out-File "$outDir\index.html" -Encoding utf8
Write-Output "stats updated: $todayKey PV=$todayPV UV=$todayUV totalPV=$totalPV"
