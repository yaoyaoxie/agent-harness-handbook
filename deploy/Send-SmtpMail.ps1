# Send-SmtpMail.ps1 — 163 邮箱 465 端口隐式 SSL 发信函数（.NET SmtpClient 不支持隐式 SSL，手写 SMTP 对话）
# 用法：. C:\stats\Send-SmtpMail.ps1; Send-SmtpMail -To x@163.com -Subject "标题" -Body "正文"
# 配置：C:\stats\smtp.json {"host":"smtp.163.com","port":465,"user":"...","pass":"授权码","to":"..."}

function Send-SmtpMail {
    param([string]$To, [string]$Subject, [string]$Body)
    $cfg = Get-Content C:\stats\smtp.json -Raw | ConvertFrom-Json

    $client = New-Object System.Net.Sockets.TcpClient($cfg.host, [int]$cfg.port)
    $ssl = New-Object System.Net.Security.SslStream($client.GetStream(), $false, { param($s,$c,$ch,$e) $true })
    $ssl.AuthenticateAsClient($cfg.host)
    $reader = New-Object System.IO.StreamReader($ssl, [System.Text.Encoding]::ASCII)
    $writer = New-Object System.IO.StreamWriter($ssl, [System.Text.Encoding]::ASCII)
    $writer.AutoFlush = $true

    function Read-Reply {
        $line = $reader.ReadLine()
        while ($line -match '^\d{3}-') { $line = $reader.ReadLine() }
        return $line
    }

    Read-Reply | Out-Null                                    # 220 欢迎
    $writer.WriteLine("EHLO harness"); Read-Reply | Out-Null
    $writer.WriteLine("AUTH LOGIN"); Read-Reply | Out-Null
    $writer.WriteLine([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cfg.user))); Read-Reply | Out-Null
    $writer.WriteLine([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($cfg.pass)))
    $auth = Read-Reply
    if ($auth -notmatch '^235') { throw "SMTP 认证失败: $auth" }

    $writer.WriteLine("MAIL FROM:<$($cfg.user)>"); Read-Reply | Out-Null
    $writer.WriteLine("RCPT TO:<$To>"); Read-Reply | Out-Null
    $writer.WriteLine("DATA"); Read-Reply | Out-Null

    $subjectB64 = "=?UTF-8?B?" + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Subject)) + "?="
    $writer.WriteLine("From: $($cfg.user)")
    $writer.WriteLine("To: $To")
    $writer.WriteLine("Subject: $subjectB64")
    $writer.WriteLine("Content-Type: text/plain; charset=utf-8")
    $writer.WriteLine("Content-Transfer-Encoding: base64")
    $writer.WriteLine("")
    $bodyB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Body))
    # 按 76 字符折行（SMTP base64 规范）
    for ($i = 0; $i -lt $bodyB64.Length; $i += 76) {
        $len = [Math]::Min(76, $bodyB64.Length - $i)
        $writer.WriteLine($bodyB64.Substring($i, $len))
    }
    $writer.WriteLine(".")
    $send = Read-Reply
    if ($send -notmatch '^250') { throw "SMTP 发送失败: $send" }
    $writer.WriteLine("QUIT")
    $ssl.Dispose(); $client.Close()
    return $true
}
