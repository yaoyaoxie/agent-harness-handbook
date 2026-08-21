# Send-WeeklyReport.ps1 — 每周流量周报邮件（周一 09:00 运行）
# 配置：C:\stats\smtp.json {"host":"smtp.163.com","port":587,"user":"...","pass":"授权码","to":"..."}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logPath = "C:\nginx\logs\access.log"
$cfgPath = "C:\stats\smtp.json"
if (-not (Test-Path $cfgPath)) { Write-Output "no smtp.json"; exit 1 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

$pattern = '^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) [^"]*" (\d{3}) (\S+) "([^"]*)" "([^"]*)"'
$botRe = '(?i)bot|spider|crawler|slurp|curl|wget|python|go-http-client|okhttp|headless|scanner|checker|ctwatch|recordedfuture|symbian|nokia|scrapy|httpclient|axios|node-fetch|java/|libwww|win-acme'
$culture = [Globalization.CultureInfo]::InvariantCulture

$cut = (Get-Date).AddDays(-7)
$prevCut = (Get-Date).AddDays(-14)

$pv7 = 0; $pvPrev = 0; $ips7 = @{}; $ipsPrev = @{}
$utm = @{}; $pages = @{}; $refs = @{}

Get-Content $logPath | ForEach-Object {
    if ($_ -match $pattern) {
        $dt = $null
        try { $dt = [datetime]::ParseExact($Matches[2].Substring(0, 20), 'dd/MMM/yyyy:HH:mm:ss', $culture) } catch { }
        if (-not $dt -or $dt -lt $prevCut) { return }
        $ip = $Matches[1]; $method = $Matches[3]; $uri = $Matches[4]; $status = $Matches[5]; $ua = $Matches[8]
        if ($uri -like '/.well-known/*' -or $ip -eq '127.0.0.1' -or $ip -eq '43.156.82.156') { return }
        $isPage = ($method -eq 'GET') -and ($status -eq '200') -and `
                  ($uri -notmatch '\.(js|css|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|map|xml|txt|json|zip|webmanifest|pdf)(\?|$)') -and `
                  ($uri -notlike '/assets/*')
        if (-not $isPage -or $ua -match $botRe) { return }

        if ($dt -ge $cut) {
            $pv7++; $ips7[$ip] = $true
            if ($uri -match '[?&]utm_source=([^&]+)') {
                $s = [System.Web.HttpUtility]::UrlDecode($Matches[1])
                if (-not $utm.ContainsKey($s)) { $utm[$s] = 0 }; $utm[$s]++
            }
            $p = ($uri -split '\?')[0]
            if (-not $pages.ContainsKey($p)) { $pages[$p] = 0 }; $pages[$p]++
        } else {
            $pvPrev++; $ipsPrev[$ip] = $true
        }
    }
}

$uv7 = $ips7.Count; $uvPrev = $ipsPrev.Count
$pct = if ($pvPrev -gt 0) { [math]::Round(($pv7 - $pvPrev) / $pvPrev * 100) } else { 0 }
$pctTxt = if ($pct -ge 0) { "+$pct%" } else { "$pct%" }

$utmTxt = if ($utm.Count -gt 0) { ($utm.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Key): $($_.Value)" }) -join '；' } else { '暂无 UTM 渠道数据' }
$pageTxt = ($pages.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Key)（$($_.Value)）" }) -join '；'

$weekStart = $cut.ToString('yyyy-MM-dd'); $weekEnd = (Get-Date).ToString('yyyy-MM-dd')
$subject = "Agent Harness 手册周报（$weekStart ~ $weekEnd）：PV $pv7 / UV $uv7"
$body = @"
上周流量概览（$weekStart ~ $weekEnd）

■ 规模
  PV（页面浏览量）：$pv7（前一周 $pvPrev，环比 $pctTxt）
  UV（独立访客）：$uv7（前一周 $uvPrev）

■ UTM 渠道 TOP5
  $utmTxt

■ 热门页面 TOP5
  $pageTxt

■ 完整看板
  https://harness.zhigouread.com/stats/

— 本邮件由服务器每周一自动生成
"@

try {
    $mail = New-Object System.Net.Mail.MailMessage($cfg.user, $cfg.to, $subject, $body)
    $mail.BodyEncoding = [System.Text.Encoding]::UTF8
    $mail.SubjectEncoding = [System.Text.Encoding]::UTF8
    $smtp = New-Object System.Net.Mail.SmtpClient($cfg.host, [int]$cfg.port)
    $smtp.EnableSsl = $true
    $smtp.Credentials = New-Object System.Net.NetworkCredential($cfg.user, $cfg.pass)
    $smtp.Send($mail)
    Write-Output "weekly report sent: PV=$pv7 UV=$uv7"
} catch {
    Write-Output ("mail error: " + $_.Exception.Message)
}
