        $oemCodeP = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        Write-Host "($oemCodeP)"
        $psV  = "PowerShell $($PSVersionTable.PSVersion.ToString())"
        Write-Host "($psV)"
Write-Host "Press any key to continue..." -NoNewline
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
