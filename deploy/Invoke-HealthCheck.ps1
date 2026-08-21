# Invoke-HealthCheck.ps1 — 每日健康巡检（异常才发邮件）
# 检查：网站可达性、Nginx 进程、SSH 服务、磁盘空间、证书有效期
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cfgPath = "C:\stats\smtp.json"
$problems = @()

# 1. 网站可达性
try {
    $r = Invoke-WebRequest -Uri "https://harness.zhigouread.com/" -UseBasicParsing -TimeoutSec 20
    if ($r.StatusCode -ne 200) { $problems += "网站返回非 200：$($r.StatusCode)" }
} catch {
    $problems += "网站不可达：$($_.Exception.Message)"
}

# 2. Nginx 进程
if (-not (Get-Process nginx -ErrorAction SilentlyContinue)) { $problems += "Nginx 进程不存在" }

# 3. SSH 服务
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if (-not $sshd -or $sshd.Status -ne 'Running') { $problems += "sshd 服务未运行" }

# 4. 磁盘空间（C 盘低于 5GB 告警）
$disk = Get-PSDrive C
$freeGB = [math]::Round($disk.Free / 1GB, 1)
if ($disk.Free -lt 5GB) { $problems += "C 盘剩余空间不足：${freeGB}GB" }

# 5. 证书有效期（读 win-acme 签发的 PEM，解析 notAfter，<14 天告警）
$certFile = "C:\nginx\ssl\harness.zhigouread.com-crt.pem"
if (Test-Path $certFile) {
    try {
        $pem = Get-Content $certFile -Raw
        $bytes = [Convert]::FromBase64String(($pem -replace '-----[^-]+-----', '' -replace '\s', ''))
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($bytes)
        $daysLeft = [math]::Round(($cert.NotAfter - (Get-Date)).TotalDays)
        if ($daysLeft -lt 14) { $problems += "HTTPS 证书仅剩 $daysLeft 天（正常应由 win-acme 自动续期）" }
    } catch { }
}

if ($problems.Count -eq 0) {
    Write-Output "health ok (disk ${freeGB}GB free)"
    exit 0
}

# 异常：发邮件
$subject = "【告警】harness.zhigouread.com 健康巡检发现 $($problems.Count) 个问题"
$body = "发现时间：" + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + "`n`n" + ($problems -join "`n") + "`n`n请尽快检查服务器（ssh -i ~/.ssh/id_ed25519 Administrator@43.156.82.156）"

try {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    $mail = New-Object System.Net.Mail.MailMessage($cfg.user, $cfg.to, $subject, $body)
    $mail.BodyEncoding = [System.Text.Encoding]::UTF8
    $mail.SubjectEncoding = [System.Text.Encoding]::UTF8
    $smtp = New-Object System.Net.Mail.SmtpClient($cfg.host, [int]$cfg.port)
    $smtp.EnableSsl = $true
    $smtp.Credentials = New-Object System.Net.NetworkCredential($cfg.user, $cfg.pass)
    $smtp.Send($mail)
    Write-Output ("alert sent: " + ($problems -join '; '))
} catch {
    Write-Output ("PROBLEMS (mail failed): " + ($problems -join '; ') + " | " + $_.Exception.Message)
}
