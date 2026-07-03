 # ↓ここでOEMコードを取得してその変数を定義
$oemCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
try {
    $psi.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding($oemCodePage)
    # ↑指定
} catch {
    # ↓if的なやつ ここはこれもうわかんねぇな
    Write-Host "!! OEMコードページ($oemCodePage)の取得に失敗、UTF-8にフォールバック" -ForegroundColor DarkYellow
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
}