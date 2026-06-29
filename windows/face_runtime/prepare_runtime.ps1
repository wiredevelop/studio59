param(
    [string]$PythonVersion = "3.11.9",
    [string]$Architecture = "amd64"
)

$ErrorActionPreference = "Stop"

$runtimeRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$downloadRoot = Join-Path $runtimeRoot "downloads"
$pythonRoot = Join-Path $runtimeRoot "python"
$requirementsFile = Join-Path $runtimeRoot "requirements.txt"

New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null
New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null

$embedName = "python-$PythonVersion-embed-$Architecture.zip"
$embedUrl = "https://www.python.org/ftp/python/$PythonVersion/$embedName"
$embedZip = Join-Path $downloadRoot $embedName

if (!(Test-Path $embedZip)) {
    Invoke-WebRequest -Uri $embedUrl -OutFile $embedZip
}

if (Test-Path $pythonRoot) {
    Get-ChildItem -Force $pythonRoot | Remove-Item -Recurse -Force
}

Expand-Archive -Path $embedZip -DestinationPath $pythonRoot -Force

$pthFile = Get-ChildItem -Path $pythonRoot -Filter "python*._pth" | Select-Object -First 1
if ($null -eq $pthFile) {
    throw "Ficheiro python._pth não encontrado."
}

$pthLines = Get-Content $pthFile.FullName
$updatedPth = @()
$hasSite = $false
$hasDot = $false
foreach ($line in $pthLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "import site") {
        $hasSite = $true
        $updatedPth += "import site"
        continue
    }
    if ($trimmed -eq "#import site") {
        $hasSite = $true
        $updatedPth += "import site"
        continue
    }
    if ($trimmed -eq ".") {
        $hasDot = $true
    }
    $updatedPth += $line
}
if (!$hasDot) {
    $updatedPth += "."
}
if (!$hasSite) {
    $updatedPth += "import site"
}
Set-Content -Path $pthFile.FullName -Value $updatedPth

$pythonExe = Join-Path $pythonRoot "python.exe"
if (!(Test-Path $pythonExe)) {
    throw "python.exe não encontrado após extração."
}

$getPip = Join-Path $downloadRoot "get-pip.py"
if (!(Test-Path $getPip)) {
    Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPip
}

& $pythonExe $getPip
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao instalar pip."
}

& $pythonExe -m pip install --upgrade pip setuptools wheel
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao atualizar pip/setuptools/wheel."
}

& $pythonExe -m pip install -r $requirementsFile
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao instalar dependências do face runtime."
}

Write-Host "Runtime preparado em: $pythonRoot"
