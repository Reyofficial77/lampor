param(
    [string]$GodotExe = "C:\Users\ASUS VIVOBOOK\Documents\Godot\Godot_v4.7.2-stable_win64.exe",
    [string]$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectDir

Write-Host "[1/2] Memeriksa referensi autoload di skrip non-autoload..."
$nonAutoloadFiles = Get-ChildItem -Path "scripts" -Recurse -Filter "*.gd" |
    Where-Object { $_.FullName -notmatch "\\autoload\\" } |
    Select-Object -ExpandProperty FullName
$bareRefs = Select-String -Path $nonAutoloadFiles -Pattern "\b(AccountManager|MultiplayerManager)\b"
if ($bareRefs) {
    $bareRefs | ForEach-Object { Write-Error "Referensi autoload langsung ditemukan: $($_.Path):$($_.LineNumber): $($_.Line)" }
    exit 1
}

Write-Host "[2/2] Menjalankan verifikasi Godot headless (live streaming)..."
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $GodotExe
$psi.WorkingDirectory = $ProjectDir
$psi.Arguments = "--headless --audio-driver Dummy -s res://tools/verify_lampor.gd"
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi

$hasScriptError = $false
$passedMarker = $false
$syncLock = New-Object Object

$outAction = {
    if ($null -ne $EventArgs.Data) {
        [System.Threading.Monitor]::Enter($Event.MessageData.Lock)
        try {
            [Console]::WriteLine($EventArgs.Data)
            if ($EventArgs.Data -match "ALL_CHECKS_PASSED") {
                $Event.MessageData.Passed.Value = $true
            }
        } finally {
            [System.Threading.Monitor]::Exit($Event.MessageData.Lock)
        }
    }
}
$errAction = {
    if ($null -ne $EventArgs.Data) {
        [System.Threading.Monitor]::Enter($Event.MessageData.Lock)
        try {
            [Console]::Error.WriteLine("[STDERR] " + $EventArgs.Data)
            if ($EventArgs.Data -match "SCRIPT ERROR:|CHECK_FAILED:|Parse Error:") {
                $Event.MessageData.HasError.Value = $true
            }
        } finally {
            [System.Threading.Monitor]::Exit($Event.MessageData.Lock)
        }
    }
}

$passedRef = [ref]$false
$errorRef = [ref]$false
$state = @{ Lock = $syncLock; Passed = $passedRef; HasError = $errorRef }

$outSub = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $outAction -MessageData $state
$errSub = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $errAction -MessageData $state

$null = $proc.Start()
$proc.BeginOutputReadLine()
$proc.BeginErrorReadLine()
$proc.WaitForExit()
$proc.WaitForExit()
$sw.Stop()

Unregister-Event -SourceIdentifier $outSub.Name
Unregister-Event -SourceIdentifier $errSub.Name

Write-Host "GODOT_EXIT=$($proc.ExitCode) ELAPSED_MS=$($sw.ElapsedMilliseconds)"
if ($proc.ExitCode -ne 0 -or $errorRef.Value -or -not $passedRef.Value) {
    Write-Error "Verifikasi gagal (exit=$($proc.ExitCode), scriptError=$($errorRef.Value), passed=$($passedRef.Value))."
    exit 1
}
Write-Host "VERIFICATION_SUCCESS"
exit 0
