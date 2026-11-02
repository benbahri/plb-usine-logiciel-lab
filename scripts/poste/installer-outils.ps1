<#
.SYNOPSIS  Installe Git (avec Git Bash), Visual Studio Code, JDK 21 et Docker Desktop via winget, puis Maven via installer-maven.ps1.
.USAGE     powershell -ExecutionPolicy Bypass -File .\installer-outils.ps1 [-SansDocker] [-DryRun]
Nécessite Windows 10/11 avec winget. Docker Desktop exige WSL2 et peut demander un redémarrage.
Les identifiants winget ci-dessous n'ont pas pu être testés depuis le poste de rédaction :
en cas d'échec, vérifier avec 'winget search <nom>'.
#>
param([switch]$SansDocker, [switch]$DryRun)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget introuvable. Installer 'Programme d'installation d'application' depuis le Microsoft Store, ou installer les outils à la main." -ForegroundColor Red
    exit 1
}

$paquets = @(
    @{ Nom = 'Git (inclut Git Bash)'; Id = 'Git.Git';                   Cmd = 'git' },
    @{ Nom = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode';   Cmd = 'code' },
    @{ Nom = 'JDK 21 (Temurin)'; Id = 'EclipseAdoptium.Temurin.21.JDK'; Cmd = 'java' }
)
if (-not $SansDocker) { $paquets += @{ Nom = 'Docker Desktop'; Id = 'Docker.DockerDesktop'; Cmd = 'docker' } }

foreach ($p in $paquets) {
    if (Get-Command $p.Cmd -ErrorAction SilentlyContinue) { Write-Host "[skip] $($p.Nom) déjà présent" -ForegroundColor DarkGray; continue }
    Write-Host "[inst] $($p.Nom) ($($p.Id))" -ForegroundColor Cyan
    if ($DryRun) { continue }
    winget install --id $p.Id -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Host "Échec pour $($p.Nom) (code $LASTEXITCODE)" -ForegroundColor Red }
}

# Maven : pas de paquet winget fiable, installation directe depuis Maven Central
& (Join-Path $PSScriptRoot 'installer-maven.ps1') -DryRun:$DryRun

# Git Bash est livré avec Git for Windows. On cherche bash.exe à côté de git.exe
# (et non `bash` dans le PATH, qui peut désigner le bash de WSL).
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $bashGit = Join-Path (Split-Path (Split-Path $git.Source)) 'bin\bash.exe'
    if (Test-Path $bashGit) { Write-Host "[ ok ] Git Bash : $bashGit" -ForegroundColor DarkGray }
    else { Write-Host "Git Bash introuvable à côté de Git : relancer l'installeur Git et conserver l'option « Git Bash Here »." -ForegroundColor Yellow }
} elseif (-not $DryRun) {
    Write-Host "Git Bash sera disponible après réouverture du terminal (installé avec Git)." -ForegroundColor Yellow
}

if (-not $SansDocker) {
    $wsl = (wsl --status 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { Write-Host "WSL2 absent : exécuter 'wsl --install' dans un terminal administrateur, puis redémarrer." -ForegroundColor Yellow }
}

Write-Host "`nFermer puis rouvrir le terminal (PATH), lancer Docker Desktop une fois, puis :" -ForegroundColor Green
Write-Host "  .\verifier-prerequis.ps1"
