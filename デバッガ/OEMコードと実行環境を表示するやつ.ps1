        $oemCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        Write-Host "($oemCodePage)"
        $psVer  = "PowerShell $($PSVersionTable.PSVersion.ToString())"
        Write-Host "($psVer)"
Write-Host "Press any key to continue..." -NoNewline
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
