# Update-TrackStats.ps1 v4 — 解析 track.log（前端埋点信号），按项目生成访问统计看板
# v4 新增：会话分析、新访客 vs 回访客、环比、设备分布、阅读深度（停留时长/滚动深度）
# 看板地址：https://harness.zhigouread.com/stats/sites/<项目名>/
# 每 5 分钟由计划任务调用，也可手动执行：powershell -ExecutionPolicy Bypass -File C:\stats\Update-TrackStats.ps1

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logPath   = "C:\nginx\logs\track.log"
$outRoot   = "C:\web\stats\sites"
$cacheFile = "C:\stats\geo-cache.json"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

if (-not (Test-Path $logPath)) {
    "<p>暂无数据</p>" | Out-File "$outRoot\index.html" -Encoding utf8
    exit 0
}

# ===== GeoIP 缓存（与主站统计共用）=====
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
$culture = [Globalization.CultureInfo]::InvariantCulture
$months  = @{ Jan=1; Feb=2; Mar=3; Apr=4; May=5; Jun=6; Jul=7; Aug=8; Sep=9; Oct=10; Nov=11; Dec=12 }
function DayKey($d) {
    $p = $d -split '/'
    '{0}-{1:D2}-{2:D2}' -f [int]$p[2], $months[$p[1]], [int]$p[0]
}

$sites = @{}
$totalHits = 0

Get-Content $logPath | ForEach-Object {
    if ($_ -notmatch $pattern) { return }
    $ip     = $Matches[1]
    $timeL  = $Matches[2]
    $method = $Matches[3]
    $uri    = $Matches[4]
    $status = $Matches[5]
    $refHdr = $Matches[7]
    $ua     = $Matches[8]

    if ($method -ne 'GET' -or $uri -notlike '/t/hit?*') { return }
    $totalHits++

    $qs = @{}
    foreach ($pair in (($uri -split '\?')[1] -split '&')) {
        $kv = $pair -split '=', 2
        if ($kv.Count -eq 2) { $qs[$kv[0]] = [System.Web.HttpUtility]::UrlDecode($kv[1]) }
    }
    $site = $qs['s']
    if (-not $site -or $site -notmatch '^[a-z0-9][a-z0-9-]*$') { return }

    if (-not $sites.ContainsKey($site)) {
        $sites[$site] = @{
            daily = @{}; allIPs = @{}; ipPV = @{}; firstSeen = @{}; topPages = @{}
            referers = @{}; directCnt = 0; hourly = @{}
            utmPV = @{}; utmIPs = @{}
            events = New-Object System.Collections.Generic.List[object]
            recent = New-Object System.Collections.Generic.List[object]
            devPV = @{ '微信内置浏览器' = 0; '移动端（非微信）' = 0; '桌面端' = 0 }
            devIPs = @{ '微信内置浏览器' = @{}; '移动端（非微信）' = @{}; '桌面端' = @{} }
            durations = New-Object System.Collections.Generic.List[int]
            depths = New-Object System.Collections.Generic.List[int]
            noiseReq = 0
        }
    }
    $S = $sites[$site]

    if ($selfIPs.ContainsKey($ip)) { return }
    if ($ua -match $botRe) { $S.noiseReq++; return }

    $event = if ($qs['e']) { $qs['e'] } else { 'view' }
    $day = $timeL.Substring(0, 11)
    $dayK = DayKey $day

    # leave 事件：只用于停留/深度统计，不计 PV
    if ($event -eq 'leave') {
        $t = 0; $dp = 0
        if ($qs['t'] -match '^\d+$') { $t = [int]$qs['t'] }
        if ($qs['d'] -match '^\d+$') { $dp = [int]$qs['d'] }
        if ($t -gt 0 -and $t -le 1800) { $S.durations.Add($t) }
        if ($dp -gt 0 -and $dp -le 100) { $S.depths.Add($dp) }
        return
    }

    if (-not $S.daily.ContainsKey($day)) { $S.daily[$day] = @{ PV = 0; IPs = @{} } }
    $S.daily[$day].PV++
    $S.daily[$day].IPs[$ip] = $true
    $S.allIPs[$ip] = $true
    if (-not $S.ipPV.ContainsKey($ip)) { $S.ipPV[$ip] = 0 }
    $S.ipPV[$ip]++
    if (-not $S.firstSeen.ContainsKey($ip)) { $S.firstSeen[$ip] = $dayK }

    $path = if ($qs['p']) { $qs['p'] } else { '/' }
    if (-not $S.topPages.ContainsKey($path)) { $S.topPages[$path] = 0 }
    $S.topPages[$path]++

    $todayKey = (Get-Date).ToString('yyyy-MM-dd')
    if ($dayK -eq $todayKey) {
        $hh = [int]$timeL.Substring(12, 2)
        if (-not $S.hourly.ContainsKey($hh)) { $S.hourly[$hh] = 0 }
        $S.hourly[$hh]++
    }

    # UTM 渠道标记（p 参数含 query string）
    if ($qs['p'] -match '[?&]utm_source=([^&]+)') {
        $utm = [System.Web.HttpUtility]::UrlDecode($Matches[1])
        if (-not $S.utmPV.ContainsKey($utm)) { $S.utmPV[$utm] = 0; $S.utmIPs[$utm] = @{} }
        $S.utmPV[$utm]++
        $S.utmIPs[$utm][$ip] = $true
    }

    $ref = $qs['r']
    if (-not $ref) { $ref = $refHdr }
    if (-not $ref -or $ref -eq '-') {
        $S.directCnt++
    } elseif ($ref -match '^https?://([^/]+)') {
        $host_ = $Matches[1]
        if (-not $S.referers.ContainsKey($host_)) { $S.referers[$host_] = 0 }
        $S.referers[$host_]++
    }

    $dev = '桌面端'
    if ($ua -match '(?i)MicroMessenger') { $dev = '微信内置浏览器' }
    elseif ($ua -match '(?i)Mobile|iPhone|Android|iPad') { $dev = '移动端（非微信）' }
    $S.devPV[$dev]++
    $S.devIPs[$dev][$ip] = $true

    $dt = $null
    try { $dt = [datetime]::ParseExact($timeL.Substring(0, 20), 'dd/MMM/yyyy:HH:mm:ss', $culture) } catch { }
    if ($dt) { $S.events.Add([PSCustomObject]@{ DT = $dt; IP = $ip; Path = $path }) }

    $S.recent.Add([PSCustomObject]@{
        Time = ('{0} {1}' -f $dayK, $timeL.Substring(12, 8))
        IP   = $ip
        URI  = $path
        UA   = $ua
    })
}

# ===== GeoIP 查询 =====
$lookupCount = 0
foreach ($site in $sites.Keys) {
    foreach ($ip in @($sites[$site].allIPs.Keys)) {
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
}
$cacheOut = @()
foreach ($k in $geo.Keys) { $cacheOut += [PSCustomObject]@{ IP = $k; Label = $geo[$k] } }
if ($cacheOut.Count -gt 0) { @($cacheOut) | ConvertTo-Json -Depth 3 | Out-File $cacheFile -Encoding utf8 }

function Get-Geo($ip) { if ($geo.ContainsKey($ip)) { return $geo[$ip] }; return '待识别' }

# ===== 每个项目生成一套看板 =====
$generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$indexRows = New-Object System.Collections.Generic.List[string]

foreach ($site in $sites.Keys) {
    $S = $sites[$site]
    $todayKey = (Get-Date).ToString('yyyy-MM-dd')
    $todayPV = 0; $todayUV = 0; $totalPV = 0

    # 会话分析
    $totalSessions = 0; $bounceSessions = 0; $landingPages = @{}
    foreach ($g in ($S.events | Group-Object IP)) {
        $sorted = $g.Group | Sort-Object DT
        $sessionPages = 0; $lastDT = $null
        foreach ($e in $sorted) {
            if ($null -eq $lastDT -or ($e.DT - $lastDT).TotalMinutes -gt 30) {
                if ($sessionPages -eq 1) { $bounceSessions++ }
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
    $pagesPerSession = 0; $bounceRate = 0
    if ($totalSessions -gt 0) {
        $pagesPerSession = [math]::Round($S.events.Count / $totalSessions, 1)
        $bounceRate = [math]::Round($bounceSessions / $totalSessions * 100)
    }

    # 今日新访客 vs 回访客
    $todayNew = 0; $todayBack = 0
    foreach ($d in $S.daily.Keys) {
        if ((DayKey $d) -eq $todayKey) {
            foreach ($ip in $S.daily[$d].IPs.Keys) {
                if ($S.firstSeen[$ip] -eq $todayKey) { $todayNew++ } else { $todayBack++ }
            }
        }
    }

    # 近 7 日环比
    $pv7 = 0; $pvPrev7 = 0
    $cut7 = (Get-Date).AddDays(-6).ToString('yyyy-MM-dd')
    $cut14 = (Get-Date).AddDays(-13).ToString('yyyy-MM-dd')
    foreach ($d in $S.daily.Keys) {
        $k = DayKey $d
        if ($k -ge $cut7) { $pv7 += $S.daily[$d].PV }
        elseif ($k -ge $cut14) { $pvPrev7 += $S.daily[$d].PV }
    }
    $wowText = '—'
    if ($pvPrev7 -gt 0) {
        $pct = [math]::Round(($pv7 - $pvPrev7) / $pvPrev7 * 100)
        if ($pct -ge 0) { $wowText = "+$pct%" } else { $wowText = "$pct%" }
    }

    # 阅读深度
    $avgStay = 0; $readThrough = 0; $depthBuckets = @(0, 0, 0, 0)
    if ($S.durations.Count -gt 0) {
        $avgStay = [math]::Round(($S.durations | Measure-Object -Average).Average)
    }
    if ($S.depths.Count -gt 0) {
        $full = 0
        foreach ($dp in $S.depths) {
            if ($dp -ge 90) { $full++ }
            if ($dp -lt 25) { $depthBuckets[0]++ }
            elseif ($dp -lt 50) { $depthBuckets[1]++ }
            elseif ($dp -lt 75) { $depthBuckets[2]++ }
            else { $depthBuckets[3]++ }
        }
        $readThrough = [math]::Round($full / $S.depths.Count * 100)
    }
    $maxBucket = 1
    foreach ($b in $depthBuckets) { if ($b -gt $maxBucket) { $maxBucket = $b } }

    # 聚合
    $sortedDays = $S.daily.Keys | Sort-Object { DayKey $_ }
    $maxPV = 1
    foreach ($d in $sortedDays) { if ($S.daily[$d].PV -gt $maxPV) { $maxPV = $S.daily[$d].PV } }

    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($d in $sortedDays) {
        $key = DayKey $d
        $pv  = $S.daily[$d].PV
        $uv  = $S.daily[$d].IPs.Count
        $totalPV += $pv
        if ($key -eq $todayKey) { $todayPV = $pv; $todayUV = $uv }
        $barWidth = [math]::Round(($pv / $maxPV) * 100)
        $rows.Add(("<tr><td>{0}</td><td class='num'>{1}</td><td class='num'>{2}</td><td class='barcell'><div class='bar' style='width:{3}%'></div></td></tr>" -f $key, $pv, $uv, $barWidth))
    }
    $rows.Reverse()

    $recent30 = $sortedDays | Select-Object -Last 30
    $pv30 = 0; foreach ($d in $recent30) { $pv30 += $S.daily[$d].PV }

    # 今日分时段
    $hourCells = New-Object System.Collections.Generic.List[string]
    $maxH = 1
    foreach ($h in $S.hourly.Keys) { if ($S.hourly[$h] -gt $maxH) { $maxH = $S.hourly[$h] } }
    for ($h = 0; $h -lt 24; $h++) {
        $c = 0; if ($S.hourly.ContainsKey($h)) { $c = $S.hourly[$h] }
        $height = [math]::Max(2, [math]::Round(($c / $maxH) * 60))
        $hourCells.Add(("<div class='hcol' title='{0}点: {1} 次'><div class='hbar' style='height:{2}px'></div><div class='hlabel'>{0}</div></div>" -f $h, $c, $height))
    }

    # 地域分布
    $geoStat = @{}
    foreach ($ip in $S.allIPs.Keys) {
        $label = Get-Geo $ip
        if (-not $geoStat.ContainsKey($label)) { $geoStat[$label] = @{ UV = 0; PV = 0 } }
        $geoStat[$label].UV++
        $geoStat[$label].PV += $S.ipPV[$ip]
    }
    $geoRows = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($kv in ($geoStat.GetEnumerator() | Sort-Object { $_.Value.PV } -Descending | Select-Object -First 10)) {
        $i++
        $geoRows.Add(("<tr><td class='num'>{0}</td><td>{1}</td><td class='num'>{2}</td><td class='num'>{3}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value.UV, $kv.Value.PV))
    }

    # 热门页面
    $pageRows = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($kv in ($S.topPages.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
        $i++
        $pageRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
    }

    # 入口页面
    $landingRows = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($kv in ($landingPages.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
        $i++
        $landingRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
    }

    # 设备分布
    $devRows = New-Object System.Collections.Generic.List[string]
    $devTotal = ($S.devPV['微信内置浏览器'] + $S.devPV['移动端（非微信）'] + $S.devPV['桌面端'])
    if ($devTotal -eq 0) { $devTotal = 1 }
    foreach ($k in @('微信内置浏览器', '移动端（非微信）', '桌面端')) {
        $share = [math]::Round($S.devPV[$k] / $devTotal * 100)
        $devRows.Add(("<tr><td>{0}</td><td class='num'>{1}</td><td class='num'>{2}</td><td class='barcell'><div class='bar' style='width:{3}%'></div></td><td class='num muted'>{3}%</td></tr>" -f $k, $S.devPV[$k], $S.devIPs[$k].Count, $share))
    }

    # 渠道分布（UTM）
    $utmRows = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($kv in ($S.utmPV.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) {
        $i++
        $utmRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td><td class='num'>{3}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value, $S.utmIPs[$kv.Key].Count))
    }

    # 来源
    $refRows = New-Object System.Collections.Generic.List[string]
    $i = 0
    if ($S.directCnt -gt 0) {
        $refRows.Add(("<tr><td class='num'>-</td><td>直接访问（输入网址/书签/微信内打开等无来源）</td><td class='num'>{0}</td></tr>" -f $S.directCnt))
    }
    foreach ($kv in ($S.referers.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)) {
        $i++
        $refRows.Add(("<tr><td class='num'>{0}</td><td class='path'>{1}</td><td class='num'>{2}</td></tr>" -f $i, [System.Web.HttpUtility]::HtmlEncode($kv.Key), $kv.Value))
    }

    # 最近访问
    $recentRows = New-Object System.Collections.Generic.List[string]
    $tail = $S.recent | Select-Object -Last 20
    if ($tail) {
        $tail = $tail[($tail.Count - 1)..0]
        foreach ($v in $tail) {
            $uaShort = $v.UA
            if ($uaShort.Length -gt 40) { $uaShort = $uaShort.Substring(0, 40) + '…' }
            $recentRows.Add(("<tr><td class='muted'>{0}</td><td class='path'>{1}</td><td>{2}</td><td class='path'>{3}</td><td class='muted ua'>{4}</td></tr>" -f $v.Time, $v.IP, [System.Web.HttpUtility]::HtmlEncode((Get-Geo $v.IP)), [System.Web.HttpUtility]::HtmlEncode($v.URI), [System.Web.HttpUtility]::HtmlEncode($uaShort)))
        }
    }

    $html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>访问统计 · $site</title>
<style>
  body { font-family: -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif; margin: 0; background: #f6f7f9; color: #2c3e50; }
  .wrap { max-width: 880px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .sub { color: #8a94a6; font-size: 13px; margin-bottom: 24px; }
  .sub a { color: #4a7ddb; text-decoration: none; }
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
  <h1>访问统计 · $site</h1>
  <div class="sub">数据来源：前端埋点（tracker.js）· 每 5 分钟更新 · 生成于 $generatedAt · <a href="/stats/sites/">全部项目</a></div>
  <div class="cards">
    <div class="card"><div class="label">今日 PV</div><div class="value">$todayPV</div></div>
    <div class="card"><div class="label">今日访客（UV）</div><div class="value">$todayUV</div></div>
    <div class="card"><div class="label">近 30 天 PV</div><div class="value">$pv30</div></div>
    <div class="card"><div class="label">累计 PV <em>/ 访客</em></div><div class="value">$totalPV <em>/ $($S.allIPs.Count)</em></div></div>
    <div class="card noise"><div class="label">已过滤爬虫</div><div class="value">$($S.noiseReq)</div></div>
  </div>
  <div class="cards">
    <div class="card"><div class="label">人均浏览页数</div><div class="value">$pagesPerSession</div></div>
    <div class="card"><div class="label">跳出率 <em>（只看 1 页就走）</em></div><div class="value">$bounceRate%</div></div>
    <div class="card"><div class="label">今日新访客 <em>/ 回访客</em></div><div class="value">$todayNew <em>/ $todayBack</em></div></div>
    <div class="card"><div class="label">近 7 日 PV <em>（环比前 7 日）</em></div><div class="value">$pv7 <em>$wowText</em></div></div>
  </div>
  <div class="cards">
    <div class="card"><div class="label">平均停留时长</div><div class="value">${avgStay}<em> 秒</em></div></div>
    <div class="card"><div class="label">读到底比例 <em>（滚动 ≥90%）</em></div><div class="value">$readThrough%</div></div>
    <div class="card"><div class="label">深度样本数 <em>（停留/滚动上报）</em></div><div class="value">$($S.durations.Count)</div></div>
  </div>
  <h2>阅读深度分布 <span class="muted" style="font-weight:400;font-size:12px">（每次页面浏览最深滚到哪里）</span></h2>
  <table>
    <tr><th>深度区间</th><th class="num">次数</th><th></th></tr>
    <tr><td>0% ~ 25%（刚开头就走了）</td><td class="num">$($depthBuckets[0])</td><td class="barcell"><div class="bar" style="width:$([math]::Round($depthBuckets[0]/$maxBucket*100))%"></div></td></tr>
    <tr><td>25% ~ 50%</td><td class="num">$($depthBuckets[1])</td><td class="barcell"><div class="bar" style="width:$([math]::Round($depthBuckets[1]/$maxBucket*100))%"></div></td></tr>
    <tr><td>50% ~ 75%</td><td class="num">$($depthBuckets[2])</td><td class="barcell"><div class="bar" style="width:$([math]::Round($depthBuckets[2]/$maxBucket*100))%"></div></td></tr>
    <tr><td>75% ~ 100%（基本读完）</td><td class="num">$($depthBuckets[3])</td><td class="barcell"><div class="bar" style="width:$([math]::Round($depthBuckets[3]/$maxBucket*100))%"></div></td></tr>
  </table>
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
    <tr><th>日期</th><th class="num">PV</th><th class="num">UV</th><th></th></tr>
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
  <h2>渠道分布 <span class="muted" style="font-weight:400;font-size:12px">（UTM 标记，链接带 ?utm_source=xxx 才计入）</span></h2>
  <table>
    <tr><th class="num">#</th><th>渠道</th><th class="num">PV</th><th class="num">访客数</th></tr>
    $($utmRows -join "`n")
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
    PV = 真实访客的页面浏览量（已排除爬虫/扫描）；UV = 独立访客数（按 IP 去重，无 Cookie）。<br>
    会话 = 同一访客 30 分钟内连续的浏览；跳出率 = 只看 1 页就结束的会话占比；回访客 = 今天之前来过的访客。<br>
    停留时长与滚动深度来自页面隐藏/关闭时的上报，样本可能少于 PV（老旧浏览器或异常退出时缺失）。<br>
    地域由免费 GeoIP（ip-api.com）按 IP 查询，为运营商级近似；前端埋点可能被广告拦截器拦截（漏计 10%~30%），与主站基于 Nginx 日志的统计口径不同。
  </div>
</div>
</body>
</html>
"@

    $siteDir = Join-Path $outRoot $site
    New-Item -ItemType Directory -Force -Path $siteDir | Out-Null
    $html | Out-File (Join-Path $siteDir 'index.html') -Encoding utf8

    $indexRows.Add(("<tr><td class='path'><a href='/stats/sites/{0}/'>{0}</a></td><td class='num'>{1}</td><td class='num'>{2}</td><td class='num'>{3}</td><td class='num'>{4}</td></tr>" -f $site, $todayPV, $todayUV, $totalPV, $S.allIPs.Count))
}

# ===== 项目总览页 =====
$indexHtml = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>全部项目 · 访问统计</title>
<style>
  body { font-family: -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif; margin: 0; background: #f6f7f9; color: #2c3e50; }
  .wrap { max-width: 880px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .sub { color: #8a94a6; font-size: 13px; margin-bottom: 24px; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 10px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.06); }
  th, td { padding: 10px 14px; font-size: 14px; text-align: left; }
  th { background: #f0f2f5; color: #5a6472; font-weight: 600; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; }
  tr + tr td { border-top: 1px solid #f0f2f5; }
  .path { font-family: ui-monospace, monospace; }
  a { color: #4a7ddb; text-decoration: none; }
</style>
</head>
<body>
<div class="wrap">
  <h1>全部项目 · 访问统计</h1>
  <div class="sub">生成于 $generatedAt · 点击项目名查看完整看板</div>
  <table>
    <tr><th>项目</th><th class="num">今日 PV</th><th class="num">今日 UV</th><th class="num">累计 PV</th><th class="num">累计访客</th></tr>
    $($indexRows -join "`n")
  </table>
</div>
</body>
</html>
"@
$indexHtml | Out-File "$outRoot\index.html" -Encoding utf8

Write-Output "track stats v4 updated: sites=$($sites.Count) totalHits=$totalHits newGeoLookups=$lookupCount"
