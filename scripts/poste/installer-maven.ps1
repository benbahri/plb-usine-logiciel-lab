<#
.SYNOPSIS  Installe Apache Maven sans winget (aucun paquet winget fiable n'existe pour Maven).
.USAGE     powershell -ExecutionPolicy Bypass -File .\installer-maven.ps1 [-Version 3.9.9] [-DryRun]
Télécharge l'archive officielle depuis Maven Central, vérifie sa somme SHA-512, l'extrait dans
%LOCALAPPDATA%\Programs et ajoute son dossier bin au PATH de l'utilisateur (sans droits administrateur).
Rouvrir ensuite le terminal pour que le PATH soit pris en compte.
#>
param([string]$Version = '3.9.9', [switch]$DryRun)
$ErrorActionPreference = 'Stop'

if (Get-Command mvn -ErrorAction SilentlyContinue) { Write-Host "[skip] Maven déjà présent" -ForegroundColor DarkGray; exit 0 }

$base    = "https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/$Version"
$archive = "apache-maven-$Version-bin.zip"
$dest    = Join-Path $env:LOCALAPPDATA 'Programs'
$home_   = Join-Path $dest "apache-maven-$Version"

Write-Host "[inst] Maven $Version -> $home_" -ForegroundColor Cyan
if ($DryRun) { exit 0 }

try {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) $archive
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "$base/$archive" -OutFile $tmp -UseBasicParsing

    # Somme SHA-512 publiée à côté de l'archive : on ne décompresse rien dont on ne peut pas garantir l'origine.
    $attendu = ((Invoke-WebRequest "$base/$archive.sha512" -UseBasicParsing).Content -split '\s+')[0].Trim().ToLower()
    $calcule = (Get-FileHash $tmp -Algorithm SHA512).Hash.ToLower()
    if ($attendu -ne $calcule) { throw "Somme SHA-512 incorrecte (attendue $attendu, obtenue $calcule)" }

    New-Item -ItemType Directory -Force $dest | Out-Null
    Expand-Archive $tmp -DestinationPath $dest -Force
    Remove-Item $tmp -Force

    $bin = Join-Path $home_ 'bin'
    if (-not (Test-Path (Join-Path $bin 'mvn.cmd'))) { throw "mvn.cmd introuvable dans $bin" }

    $pathUtilisateur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($pathUtilisateur -split ';') -notcontains $bin) {
        [Environment]::SetEnvironmentVariable('Path', ($pathUtilisateur.TrimEnd(';') + ';' + $bin), 'User')
    }
    $env:Path += ";$bin"
    Write-Host "Maven installé. Rouvrir le terminal, puis : mvn -v" -ForegroundColor Green
}
catch {
    Write-Host "Échec de l'installation de Maven : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Solution de repli : utiliser le conteneur maven:3.9-eclipse-temurin-21 (voir guide-installation.md)." -ForegroundColor Yellow
    exit 1
}
