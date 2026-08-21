# Push-Baidu.ps1 — 百度主动推送 + IndexNow 即时收录（服务器每日定时运行）
# 每次发布后也由 deploy.sh 远程调用。状态文件：C:\stats\baidu-pushed.txt
# 手动执行：powershell -ExecutionPolicy Bypass -File C:\stats\Push-Baidu.ps1

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sitemapPath  = "C:\web\harness\sitemap.xml"
$stateFile    = "C:\stats\baidu-pushed.txt"
$indexKeyFile = "C:\web\harness\indexnow-key.txt"
$siteHost     = "https://harness.zhigouread.com"
$baiduApi     = "http://data.zz.baidu.com/urls?site=https://harness.zhigouread.com&token=2EfqpAoBWjScvkZG"

if (-not (Test-Path $sitemapPath)) { Write-Output "no sitemap"; exit 0 }
if (-not (Test-Path $stateFile)) { New-Item -ItemType File -Path $stateFile | Out-Null }

# 解析 sitemap 中的全部 URL
$xml = Get-Content $sitemapPath -Raw -Encoding UTF8
$allUrls = [regex]::Matches($xml, '<loc>([^<]+)</loc>') | ForEach-Object { $_.Groups[1].Value }
$pushed = @{}
Get-Content $stateFile | ForEach-Object { if ($_) { $pushed[$_.Trim()] = $true } }

$todo = @($allUrls | Where-Object { -not $pushed.ContainsKey($_) })
Write-Output ("total={0} pushed={1} todo={2}" -f $allUrls.Count, $pushed.Count, $todo.Count)

# ===== 1. 百度主动推送（每日配额 10 条）=====
$batch = @($todo | Select-Object -First 10)
if ($batch.Count -gt 0) {
    $body = ($batch -join "`n")
    try {
        $resp = Invoke-RestMethod -Uri $baiduApi -Method Post -Body $body -ContentType "text/plain; charset=utf-8" -TimeoutSec 15
        Write-Output ("baidu: " + ($resp | ConvertTo-Json -Compress))
        if ($resp.success -gt 0) {
            $batch | Add-Content $stateFile -Encoding utf8
        }
    } catch {
        Write-Output ("baidu error: " + $_.Exception.Message)
    }
} else {
    Write-Output "baidu: nothing to push"
}

# ===== 2. IndexNow（Bing/Yandex 即时收录）=====
# 密钥文件须可从 https://harness.zhigouread.com/indexnow-key.txt 访问
$indexKey = "e8f2a9c4d7b14f3e9a6c5d8b2f1e4a7c"
Set-Content -Path $indexKeyFile -Value $indexKey -Encoding ascii -ErrorAction SilentlyContinue

$nowPushed = @{}
Get-Content $stateFile | ForEach-Object { if ($_) { $pushed[$_.Trim()] = $true } }
# IndexNow 每次最多提交 10000 条，把尚未被百度确认的也一起推（低成本，全部推）
$payload = @{
    host        = "harness.zhigouread.com"
    key         = $indexKey
    keyLocation = "$siteHost/indexnow-key.txt"
    urlList     = @($allUrls)
} | ConvertTo-Json -Depth 3

try {
    $r = Invoke-WebRequest -Uri "https://api.indexnow.org/indexnow" -Method Post -Body $payload -ContentType "application/json; charset=utf-8" -TimeoutSec 15 -UseBasicParsing
    Write-Output ("indexnow: HTTP " + $r.StatusCode)
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Output ("indexnow: HTTP " + $code + " (202/200=成功, 4xx=配置问题)")
}
