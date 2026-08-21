# Update-Stats.ps1 v4 — 解析 Nginx access.log，生成网站访问统计看板
# v4 新增：会话分析（人均页数/跳出率/入口页面）、新访客 vs 回访客、近 7 日环比、设备与微信分布
# 每 5 分钟由计划任务调用，也可手动执行：powershell -ExecutionPolicy Bypass -File C:\stats\Update-Stats.ps1

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logPath   = "C:\nginx\logs\access.log"
$outDir    = "C:\web\stats"
$cacheFile = "C:\stats\geo-cache.json"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (-not (Test-Path $logPath)) {
    "no log" | Out-File "$outDir\index.html" -Encoding utf8
    exit 0
}

# ===== GeoIP 缓存 =====
$geo = @{}
if (Test-Path $cacheFile) {
    try {
        $cacheData = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cacheData -and -not ($cacheData -is [array])) { $cacheData = @($cacheData) }
        foreach ($c in $cacheData) { $geo[$c.IP] = $c.Label }
    } catch { }
}

function GeoLabel($country, $region, $city) {
    if ($country -eq '中国' -or $country -eq 'China') {
        if ($city -and $region -and $city -ne $region) { return "$region $city" }
        if ($city) { return $city }
        if ($region) { return $region }
        return '中国'
    }
    if ($country) { return $country }
    return '未知'
}

$pattern = '^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) [^"]*" (\d{3}) (\S+) "([^"]*)" "([^"]*)"'
$botRe = '(?i)bot|spider|crawler|slurp|curl|wget|python|go-http-client|okhttp|headless|scanner|checker|ctwatch|recordedfuture|symbian|nokia|scrapy|httpclient|axios|node-fetch|java/|libwww|win-acme'
$selfIPs = @{ '127.0.0.1' = $true; '43.156.82.156' = $true }

$daily    = @{}
$allIPs   = @{}
$ipPV     = @{}
$firstSeen = @{}   # IP -> 首次出现日期 key
$topPages = @{}
$referers = @{}
$directCnt = 0
$hourly   = @{}
$recent   = New-Object System.Collections.Generic.List[object]
$events   = New-Object System.Collections.Generic.List[object]   # 会话分析用：全部真实页面浏览
$devPV    = @{ '微信内置浏览器' = 0; '移动端（非微信）' = 0; '桌面端' = 0 }
$devIPs   = @{ '微信内置浏览器' = @{}; '移动端（非微信）' = @{}; '桌面端' = @{} }
$totalReq = 0
$noiseReq = 0

$todayKey = (Get-Date).ToString('yyyy-MM-dd')
$culture  = [Globalization.CultureInfo]::InvariantCulture
$months   = @{ Jan=1; Feb=2; Mar=3; Apr=4; May=5; Jun=6; Jul=7; Aug=8; Sep=9; Oct=10; Nov=11; Dec=12 }
function DayKey($d) {
    $p = $d -split '/'
    '{0}-{1:D2}-{2:D2}' -f [int]$p[2], $months[$p[1]], [int]$p[0]
}

Get-Content $logPath | ForEach-Object {
    if ($_ -match $pattern) {
        $ip     = $Matches[1]
        $timeL  = $Matches[2]
        $method = $Matches[3]
        $uri    = $Matches[4]
        $status = $Matches[5]
        $ref    = $Matches[7]
        $ua     = $Matches[8]

        $day = $timeL.Substring(0, 11)
        if (-not $daily.ContainsKey($day)) {
            $daily[$day] = @{ Req = 0; PV = 0; IPs = @{}; Noise = 0 }
        }
        $daily[$day].Req++
        $totalReq++

        if ($uri -like '/.well-known/*' -or $selfIPs.ContainsKey($ip)) { return }

        $isPage = ($method -eq "GET") -and ($status -eq "200") -and `
                  ($uri -notmatch '\.(js|css|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|map|xml|txt|json|zip|webmanifest|pdf)(\?|$)') -and `
                  ($uri -notlike '/assets/*')
        if (-not $isPage) { return }

        if ($ua -match $botRe) {
            $daily[$day].Noise++
            $noiseReq++
            return
        }

        # —— 真实访客页面浏览 ——
        $dayK = DayKey $day
        $daily[$day].PV++
        $daily[$day].IPs[$ip] = $true
        $allIPs[$ip] = $true
        if (-not $ipPV.ContainsKey($ip)) { $ipPV[$ip] = 0 }
        $ipPV[$ip]++
        if (-not $firstSeen.ContainsKey($ip)) { $firstSeen[$ip] = $dayK }

        $path = ($uri -split '\?')[0]
        if (-not $topPages.ContainsKey($path)) { $topPages[$path] = 0 }
        $topPages[$path]++

        if ($dayK -eq $todayKey) {
            $hh = [int]$timeL.Substring(12, 2)
            if (-not $hourly.ContainsKey($hh)) { $hourly[$hh] = 0 }
            $hourly[$hh]++
        }

        if ($ref -eq '-') {
            $directCnt++
        } elseif ($ref -match '^https?://([^/]+)') {
            $host_ = $Matches[1]
            if ($host_ -ne 'harness.zhigouread.com') {
                if (-not $referers.ContainsKey($host_)) { $referers[$host_] = 0 }
                $referers[$host_]++
            }
        }

        # 设备分类
        $dev = '桌面端'
        if ($ua -match '(?i)MicroMessenger') { $dev = '微信内置浏览器' }
        elseif ($ua -match '(?i)Mobile|iPhone|Android|iPad') { $dev = '移动端（非微信）' }
        $devPV[$dev]++
        $devIPs[$dev][$ip] = $true

        $dt = $null
        try { $dt = [datetime]::ParseExact($timeL.Substring(0, 20), 'dd/MMM/yyyy:HH:mm:ss', $culture) } catch { }
        if ($dt) {
            $events.Add([PSCustomObject]@{ DT = $dt; IP = $ip; Path = $path })
        }

        $recent.Add([PSCustomObject]@{
            Time = ('{0} {1}' -f $dayK, $timeL.Substring(12, 8))
            IP   = $ip
            URI  = $path
            UA   = $ua
        })
    }
}

# ===== GeoIP 查询 =====
$lookupCount = 0
foreach ($ip in @($allIPs.Keys)) {
    if (-not $geo.ContainsKey($ip)) {
        if ($lookupCount -ge 40) { break }
        $lookupCount++
        try {
            $r = Invoke-RestMethod -Uri "http://ip-api.com/json/${ip}?lang=zh-CN&fields=status,country,regionName,city" -TimeoutSec 5
            if ($r.status -eq 'success') { $geo[$ip] = GeoLabel $r.country $r.regionName $r.city } else { $geo[$ip] = '未知' }
        } catch { $geo[$ip] = '未知' }
        Start-Sleep -Milliseconds 150
    }
}
$cacheOut = @()
foreach ($k in $geo.Keys) { $cacheOut += [PSCustomObject]@{ IP = $k; Label = $geo[$k] } }
if ($cacheOut.Count -gt 0) { @($cacheOut) | ConvertTo-Json -Depth 3 | Out-File $cacheFile -Encoding utf8 }

function Get-Geo($ip) { if ($geo.ContainsKey($ip)) { return $geo[$ip] }; return '待识别' }

# ===== 会话分析（30 分钟无活动切分会话）=====
$totalSessions = 0
$bounceSessions = 0
$landingPages = @{}
$byIp = $events | Group-Object IP
foreach ($g in $byIp) {
    $sorted = $g.Group | Sort-Object DT
    $sessionPages = 0
    $lastDT = $null
    foreach ($e in $sorted) {
        if ($null -eq $lastDT -or ($e.DT - $lastDT).TotalMinutes -gt 30) {
            # 新会话开启：先结算上一个会话
            if ($sessionPages -gt 0 -and $sessionPages -eq 1) { $bounceSessions++ }
            $totalSessions++
            $sessionPages = 0
            if (-not $landingPages.ContainsKey($e.Path)) { $landingPages[$e.Path] = 0 }
            $landingPages[$e.Path]++
        }
        $sessionPages++
        $lastDT = $e.DT
    }
    if ($sessionPages -eq 1) { $bounceSessions++ }
}
$pagesPerSession = 0
$bounceRate = 0
if ($totalSessions -gt 0) {
    $pagesPerSession = [math]::Round($events.Count / $totalSessions, 1)
    $bounceRate = [math]::Round($bounceSessions / $totalSessions * 100)
}

# 今日新访客 vs 回访客
$todayNew = 0; $todayBack = 0
if ($daily.Keys -contains ($todayKey -replace '-','/')) { }
foreach ($d in $daily.Keys) {
    if ((DayKey $d) -eq $todayKey) {
        foreach ($ip in $daily[$d].IPs.Keys) {
            if ($firstSeen[$ip] -eq $todayKey) { $todayNew++ } else { $todayBack++ }
        }
    }
}

# 近 7 日环比
$pv7 = 0; $pvPrev7 = 0
$cut7 = (Get-Date).AddDays(-6).ToString('yyyy-MM-dd')
$cut14 = (Get-Date).AddDays(-13).ToString('yyyy-MM-dd')
foreach ($d in $daily.Keys) {
    $k = DayKey $d
    if ($k -ge $cut7) { $pv7 += $daily[$d].PV }
    elseif ($k -ge $cut14) { $pvPrev7 += $daily[$d].PV }
}
$wowText = '—'
if ($pvPrev7 -gt 0) {
    $pct = [math]::Round(($pv7 - $pvPrev7) / $pvPrev7 * 100)
    if ($pct -ge 0) { $wowText = "+$pct%" } else { $wowText = "$pct%" }
}

# ===== 地域分布 =====
$geoStat = @{}
foreach ($ip in $allIPs.Keys) {
    $label = Get-Geo $ip
    if (-not $geoStat.ContainsKey($label)) { $geoStat[$label] = @{ UV = 0; PV = 0 } }
    $geoStat[$label].UV++
    $geoStat[$label].PV += $ipPV[$ip]
}
$geoRows = New-Object System.Collections.Generic.List[string]
$i = 0
foreach ($kv in ($geoStat.GetEnumerator() | Sort-Object { $_.Value.PV } -Descending | Select-Object -First 10)) {
    $i++
    $geoRows.Add(("<tr><td class='num'>{0}</td><td>{1}</td><td class='num'>{2}</td><td class='num'>{3}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value.UV, $kv.Value.PV))
}

# ===== 聚合 =====
$todayPV = 0; $todayUV = 0; $totalPV = 0
$rows = New-Object System.Collections.Generic.List[string]
$sortedDays = $daily.Keys | Sort-Object { DayKey $_ }
$maxPV = 1
foreach ($d in $sortedDays) { if ($daily[$d].PV -gt $maxPV) { $maxPV = $daily[$d].PV } }

foreach ($d in $sortedDays) {
    $key = DayKey $d
    $pv  = $daily[$d].PV
    $uv  = $daily[$d].IPs.Count
    $nz  = $daily[$d].Noise
    $req = $daily[$d].Req
    $totalPV += $pv
    if ($key -eq $todayKey) { $todayPV = $pv; $todayUV = $uv }
    $barWidth = [math]::Round(($pv / $maxPV) * 100)
    $rows.Add(("<tr><td>{0}</td><td class='num'>{1}</td><td class='num'>{2}</td><td class='num muted'>{3}</td><td class='num muted'>{4}</td><td class='barcell'><div class='bar' style='width:{5}%'></div></td></tr>" -f $key, $pv, $uv, $nz, $req, $barWidth))
}
$rows.Reverse()

$recent30 = $sortedDays | Select-Object -Last 30
$pv30 = 0; foreach ($d in $recent30) { $pv30 += $daily[$d].PV }

# 今日分时段
$hourCells = New-Object System.Collections.Generic.List[string]
$maxH = 1
foreach ($h in $hourly.Keys) { if ($hourly[$h] -gt $maxH) { $maxH = $hourly[$h] } }
for ($h = 0; $h -lt 24; $h++) {
    $c = 0; if ($hourly.ContainsKey($h)) { $c = $hourly[$h] }
    $height = [math]::Max(2, [math]::Round(($c / $maxH) * 60))
    $hourCells.Add(("<div class='hcol' title='{0}点: {1} 次'><div class='hbar' style='height:{2}px'></div><div class='hlabel'>{0}</div></div>" -f $h, $c, $height))
}

# 热门页面
$pageRows = New-Object System.Collections.Generic.List[string]
$i = 0
foreach ($kv in ($topPages.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
    $i++
    $pageRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
}

# 入口页面（会话的第一页）
$landingRows = New-Object System.Collections.Generic.List[string]
$i = 0
foreach ($kv in ($landingPages.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
    $i++
    $landingRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
}

# 设备与场景分布
$devRows = New-Object System.Collections.Generic.List[string]
$devTotal = ($devPV['微信内置浏览器'] + $devPV['移动端（非微信）'] + $devPV['桌面端'])
if ($devTotal -eq 0) { $devTotal = 1 }
foreach ($k in @('微信内置浏览器', '移动端（非微信）', '桌面端')) {
    $share = [math]::Round($devPV[$k] / $devTotal * 100)
    $devRows.Add(("<tr><td>{0}</td><td class='num'>{1}</td><td class='num'>{2}</td><td class='barcell'><div class='bar' style='width:{3}%'></div></td><td class='num muted'>{3}%</td></tr>" -f $k, $devPV[$k], $devIPs[$k].Count, $share))
}

# 访客来源
$refRows = New-Object System.Collections.Generic.List[string]
$i = 0
if ($directCnt -gt 0) {
    $refRows.Add(("<tr><td class='num'>-</td><td>直接访问（输入网址/书签/微信内打开等无来源）</td><td class='num'>{0}</td></tr>" -f $directCnt))
}
foreach ($kv in ($referers.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
    $i++
    $refRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
}

# 最近访问
$recentRows = New-Object System.Collections.Generic.List[string]
$tail = $recent | Select-Object -Last 20
$tail = $tail[($tail.Count - 1)..0]
foreach ($v in $tail) {
    $uaShort = $v.UA
    if ($uaShort.Length -gt 40) { $uaShort = $uaShort.Substring(0, 40) + '…' }
    $recentRows.Add(("<tr><td class='muted'>{0}</td><td class='path'>{1}</td><td>{2}</td><td class='path'>{3}</td><td class='muted ua'>{4}</td></tr>" -f $v.Time, $v.IP, [System.Web.HttpUtility]::HtmlEncode((Get-Geo $v.IP)), [System.Web.HttpUtility]::HtmlEncode($v.URI), [System.Web.HttpUtility]::HtmlEncode($uaShort)))
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
  .wrap { max-width: 880px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .sub { color: #8a94a6; font-size: 13px; margin-bottom: 24px; }
  .cards { display: flex; gap: 14px; flex-wrap: wrap; margin-bottom: 8px; }
  .card { background: #fff; border-radius: 10px; padding: 16px 20px; flex: 1; min-width: 130px; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  .card .label { font-size: 12px; color: #8a94a6; }
  .card .value { font-size: 26px; font-weight: 700; margin-top: 6px; }
  .card .value em { font-size: 13px; font-style: normal; color: #8a94a6; font-weight: 400; }
  .card.noise .value { color: #b0b8c4; }
  h2 { font-size: 16px; margin: 28px 0 12px; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  th, td { padding: 9px 14px; font-size: 13px; text-align: left; }
  th { background: #f0f2f5; color: #5a6472; font-weight: 600; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  tr + tr td { border-top: 1px solid #f0f2f5; }
  .barcell { width: 26%; }
  .bar { height: 10px; background: #4a7ddb; border-radius: 5px; min-width: 1px; }
  .path { font-family: ui-monospace, monospace; font-size: 12px; }
  .muted { color: #8a94a6; }
  .ua { font-size: 11px; max-width: 220px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .hchart { display: flex; align-items: flex-end; gap: 3px; background: #fff; border-radius: 10px; padding: 18px 16px 10px; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  .hcol { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; }
  .hbar { width: 70%; background: #4a7ddb; border-radius: 3px 3px 0 0; }
  .hlabel { font-size: 10px; color: #8a94a6; margin-top: 4px; }
  .note { color: #8a94a6; font-size: 12px; margin-top: 20px; line-height: 1.8; }
</style>
</head>
<body>
<div class="wrap">
  <h1>访问统计 · Agent Harness 手册</h1>
  <div class="sub">数据来源：服务器 Nginx 访问日志 · 每 5 分钟更新 · 生成于 $generatedAt</div>
  <div class="cards">
    <div class="card"><div class="label">今日 PV</div><div class="value">$todayPV</div></div>
    <div class="card"><div class="label">今日访客（UV）</div><div class="value">$todayUV</div></div>
    <div class="card"><div class="label">近 30 天 PV</div><div class="value">$pv30</div></div>
    <div class="card"><div class="label">累计 PV <em>/ 访客</em></div><div class="value">$totalPV <em>/ $($allIPs.Count)</em></div></div>
    <div class="card noise"><div class="label">已过滤爬虫</div><div class="value">$noiseReq</div></div>
  </div>
  <div class="cards">
    <div class="card"><div class="label">人均浏览页数</div><div class="value">$pagesPerSession</div></div>
    <div class="card"><div class="label">跳出率 <em>（只看 1 页就走）</em></div><div class="value">$bounceRate%</div></div>
    <div class="card"><div class="label">今日新访客 <em>/ 回访客</em></div><div class="value">$todayNew <em>/ $todayBack</em></div></div>
    <div class="card"><div class="label">近 7 日 PV <em>（环比前 7 日）</em></div><div class="value">$pv7 <em>$wowText</em></div></div>
  </div>
  <h2>访客地域分布</h2>
  <table>
    <tr><th class="num">#</th><th>地域</th><th class="num">访客数</th><th class="num">PV</th></tr>
    $($geoRows -join "`n")
  </table>
  <h2>今日分时段</h2>
  <div class="hchart">
    $($hourCells -join "`n")
  </div>
  <h2>每日趋势</h2>
  <table>
    <tr><th>日期</th><th class="num">PV</th><th class="num">UV</th><th class="num">爬虫/噪音</th><th class="num">总请求</th><th></th></tr>
    $($rows -join "`n")
  </table>
  <h2>热门页面 Top 10</h2>
  <table>
    <tr><th class="num">#</th><th>页面</th><th class="num">PV</th></tr>
    $($pageRows -join "`n")
  </table>
  <h2>入口页面 Top 10 <span class="muted" style="font-weight:400;font-size:12px">（一次访问的第一页）</span></h2>
  <table>
    <tr><th class="num">#</th><th>页面</th><th class="num">次数</th></tr>
    $($landingRows -join "`n")
  </table>
  <h2>设备与场景分布</h2>
  <table>
    <tr><th>场景</th><th class="num">PV</th><th class="num">访客数</th><th></th><th class="num">占比</th></tr>
    $($devRows -join "`n")
  </table>
  <h2>访客来源</h2>
  <table>
    <tr><th class="num">#</th><th>来源</th><th class="num">次数</th></tr>
    $($refRows -join "`n")
  </table>
  <h2>最近访问</h2>
  <table>
    <tr><th>时间</th><th>IP</th><th>地域</th><th>页面</th><th>UA</th></tr>
    $($recentRows -join "`n")
  </table>
  <div class="note">
    PV = 真实访客的页面浏览量（不含静态资源，已排除爬虫/扫描与系统流量）；UV = 独立访客数（按 IP 去重）。<br>
    会话 = 同一访客 30 分钟内连续的浏览；跳出率 = 只看 1 页就结束的会话占比；回访客 = 今天之前来过的访客。<br>
    地域由免费 GeoIP（ip-api.com）按 IP 查询，中国境内为运营商级近似；设备场景按 UA 判定，微信内打开可通过「微信内置浏览器」识别（微信不带来源域名）。<br>
    爬虫/噪音 = UA 含 bot/curl/scanner 等特征的页面访问；总请求 = 含静态资源的全部请求。
  </div>
</div>
</body>
</html>
"@

$html | Out-File "$outDir\index.html" -Encoding utf8
Write-Output "stats v4 updated: $todayKey PV=$todayPV UV=$todayUV sessions=$totalSessions bounce=$bounceRate% new=$todayNew back=$todayBack geoNew=$lookupCount"
