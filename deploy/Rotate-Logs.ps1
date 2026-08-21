# Rotate-Logs.ps1 — 每月 1 号日志轮转：把上月日志归档，Nginx 开新文件继续写
# 归档到 C:\nginx\logs\archive\，保留最近 12 个月

$logDir = "C:\nginx\logs"
$archiveDir = "$logDir\archive"
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

$stamp = (Get-Date).AddMonths(-1).ToString('yyyy-MM')

foreach ($name in @('access.log', 'track.log', 'error.log')) {
    $src = Join-Path $logDir $name
    if ((Test-Path $src) -and (Get-Item $src).Length -gt 0) {
        $dst = Join-Path $archiveDir "$name.$stamp"
        # Nginx 以追加模式写日志，直接移动句柄会写到旧文件；改为 复制 + 清空
        Copy-Item $src $dst -Force
        Clear-Content $src
        Write-Output "rotated: $name -> $dst"
    }
}

# 只保留最近 12 个归档文件/每种日志
foreach ($name in @('access.log', 'track.log', 'error.log')) {
    $old = Get-ChildItem $archiveDir -Filter "$name.*" | Sort-Object Name -Descending | Select-Object -Skip 12
    $old | Remove-Item -Force
}
Write-Output "rotation done"
