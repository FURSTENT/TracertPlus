# ============================================================
#  tracert++.ps1
#  tracert を実行してホップを記憶 → 各ホップに ping を打って
#  結果をまとめて表示するやつ
# ============================================================

# スピナー文字は "|" "/" "-" "\" だけどエスケープ地雷なので
# 直接コード内に書かず [char] コードポイントで安全に生成する
$script:SpinnerFrames = @(
    [char]124,  # |
    [char]47,   # /
    [char]45,   # -
    [char]92    # \
)
$script:SpinnerIndex = 0

function Write-SpinnerFrame {
    # カーソル位置を保存 → 右端っぽい位置にスピナー1文字だけ描く → 戻す
    param(
        [int]$Col = 60
    )
    $frame = $script:SpinnerFrames[$script:SpinnerIndex % $script:SpinnerFrames.Length]
    $script:SpinnerIndex++

    try {
        $origLeft = [Console]::CursorLeft
        $origTop  = [Console]::CursorTop

        # 現在行の指定カラムにスピナーを描く(画面幅を超えないようclamp)
        $width = [Console]::BufferWidth
        $targetCol = [Math]::Min($Col, [Math]::Max(0, $width - 1))

        [Console]::SetCursorPosition($targetCol, $origTop)
        Write-Host -NoNewline ("[{0}]" -f $frame) -ForegroundColor DarkCyan

        [Console]::SetCursorPosition($origLeft, $origTop)
    } catch {
        # コンソールが対応してない環境(リダイレクト中とか)は黙って諦める
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host "   tracert++ V1 Fix3 " -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  IPアドレスかホスト名を入力してください。exit で終了します。" -ForegroundColor Gray
    Write-Host ""
}

function Invoke-TracertPP {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    Write-Host ""
    Write-Host ">> tracert $Target を実行中..." -ForegroundColor Yellow
    Write-Host ""

    # ---- tracert をリアルタイムでストリーム表示しつつホップを収集 ----
    $hops = New-Object System.Collections.Generic.List[Object]

    # ホップ行パターン: "  1     1 ms     1 ms     1 ms  domain [ip]" とか
    # "  1     1 ms     1 ms     1 ms  1.1.1.1" とか
    # タイムアウト行: "  1     *        *        *     要求がタイムアウトしました。"
    $hopPattern = '^\s*(\d+)\s+(.+)$'

    try {
        # tracert の標準出力を1行ずつ受け取ってその場で表示 + 解析
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "tracert.exe"
        $psi.Arguments = "-d `"$Target`""   # -d で逆引きさせない(こっちで自前逆引きする)
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        # psi.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding(850)  tracert日本語版はOEM850系のことが多い
        # OSの現在のカルチャからOEMコードページ番号（日本なら932）を動的に取得
        $oemCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        $psi.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding($oemCodePage)

        
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()

            # 生ログをそのまま流す
            Write-Host $line

            # 脇でスピナーをチラつかせる(疑似進捗)
            Write-SpinnerFrame -Col ([Console]::BufferWidth - 4)

            if ($line -match $hopPattern) {
                $hopNum = [int]$Matches[1]
                $rest = $Matches[2]

                # IPv4アドレスを抽出
                $ipMatch = [regex]::Match($rest, '(\d{1,3}\.){3}\d{1,3}')
                if ($ipMatch.Success) {
                    $ip = $ipMatch.Value
                    $hops.Add([PSCustomObject]@{
                        HopNumber = $hopNum
                        IP        = $ip
                    })
                }
                # タイムアウトのみの行(IPなし)はホップとして記録しない
            }
        }
        $proc.WaitForExit()
    } catch {
        Write-Host ""
        Write-Host "tracert の実行に失敗しました!!: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ">> tracertが完了しました。有効なホップ数は $($hops.Count) です" -ForegroundColor Yellow
    Write-Host ">> 各ホップに ping を送っています..." -ForegroundColor Yellow
    Write-Host ""

    if ($hops.Count -eq 0) {
        Write-Host "有効なホップが見つかりませんでした。" -ForegroundColor DarkYellow
        return
    }

    # ---- 収集したホップに順番に ping ----
    $first = $true
    foreach ($hop in $hops) {
        if (-not $first) {
            # ホップ間は改行2個
            Write-Host ""
            Write-Host ""
        }
        $first = $false

        # 逆引き試行
        $domain = "[ドメイン不明]"
        try {
            $resolved = [System.Net.Dns]::GetHostEntry($hop.IP)
            if ($resolved -and $resolved.HostName) {
                $domain = $resolved.HostName
            }
        } catch {
            $domain = "[ドメイン不明]"
        }

        # ping実行(スピナー出しつつ)
        $spinnerCol = [Console]::BufferWidth - 4
        Write-Host ("{0,2}.    " -f $hop.HopNumber) -NoNewline
        Write-SpinnerFrame -Col $spinnerCol

        $pingResult = Test-HopPing -IPAddress $hop.IP

        # 結果表示 (指定フォーマット)
        # 1.     1ms     1 ms     1 ms
        Write-Host ("{0}     {1}     {2}     {3}" -f $pingResult.TimesFormatted[0], $pingResult.TimesFormatted[1], $pingResult.TimesFormatted[2], $pingResult.TimesFormatted[3])

        Write-Host (" [{0}]  {1}" -f $domain, $hop.IP)

        if ($pingResult.Success) {
            Write-Host "ping:OK" -ForegroundColor Green
        } else {
            Write-Host ("ping:NG ({0})" -f $pingResult.Reason) -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host ">> 全ホップ完了。" -ForegroundColor Yellow
    Write-Host ""
}

function Test-HopPing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )

    # Test-Connection で3回打つ(表示フォーマットに合わせて3回分の時間を出す)
    $times = @()
    $success = $true
    $reason = ""

    for ($i = 0; $i -lt 3; $i++) {
        Write-SpinnerFrame -Col ([Console]::BufferWidth - 4)
        try {
            $ping = New-Object System.Net.NetworkInformation.Ping
            $reply = $ping.Send($IPAddress, 1000)  # 1000ms timeout

            if ($reply.Status -eq 'Success') {
                if ($i -eq 0) {
                    $times += "$($reply.RoundtripTime)ms"
                } else {
                    $times += "$($reply.RoundtripTime) ms"
                }
            } else {
                $times += "*"
                $success = $false
                if ($reason -eq "") {
                    $reason = switch ($reply.Status) {
                        'TimedOut'          { 'timeout' }
                        'DestinationHostUnreachable' { 'unreachable' }
                        'DestinationNetworkUnreachable' { 'network unreachable' }
                        'TtlExpired'         { 'ttl expired' }
                        default              { $reply.Status.ToString() }
                    }
                }
            }
        } catch {
            $times += "*"
            $success = $false
            if ($reason -eq "") {
                $reason = "error"
            }
        }
    }

    # 表示は先頭に "1." のヘッダをすでに書いてるので、時刻3つのフォーマットのみ返す
    # 要求フォーマット例: "1.     1ms     1 ms     1 ms" -> 先頭要素だけ "Xms"詰め、残りは "X ms"
    $formatted = @()
    for ($i = 0; $i -lt 3; $i++) {
        $formatted += $times[$i]
    }

    if ($reason -eq "" -and -not $success) {
        $reason = "timeout"
    }

    return [PSCustomObject]@{
        Success        = $success
        Reason         = $reason
        TimesFormatted = $formatted
    }
}

function Test-IsValidTarget {
    param([string]$Target)
    if ([string]::IsNullOrWhiteSpace($Target)) { return $false }
    return $true
}

# ============================================================
#  メインループ
# ============================================================

Clear-Host
Show-Banner

$userName = $env:USERNAME
if ([string]::IsNullOrWhiteSpace($userName)) { $userName = "user" }

while ($true) {
    Write-Host ""
    Write-Host "$userName@tracert++ > " -NoNewline -ForegroundColor Green
    $userInput = Read-Host

    if ([string]::IsNullOrWhiteSpace($userInput)) { continue }

    if ($userInput -eq 'exit' -or $userInput -eq 'quit') {
        Write-Host "bye" -ForegroundColor Gray
        break
    }

    if (-not (Test-IsValidTarget -Target $userInput)) {
        Write-Host "内容が入力されていません" -ForegroundColor DarkYellow
        continue
    }

    Invoke-TracertPP -Target $userInput
}