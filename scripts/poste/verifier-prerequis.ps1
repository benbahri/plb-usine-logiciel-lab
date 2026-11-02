<#
.SYNOPSIS  Vérifie le poste Windows pour la formation Usine Logicielle (sirh-export).
.USAGE     powershell -ExecutionPolicy Bypass -File .\verifier-prerequis.ps1
Code retour : 0 = tout est OK, 1 = au moins un élément bloquant.
#>
$ErrorActionPreference = 'Continue'
$script:echecs = 0
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Ko($m)   { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:echecs++ }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Get-Version($cmd, $args_) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { return $null }
    # 2>&1 : java -version écrit sur stderr
    return (& $cmd $args_ 2>&1 | Select-Object -First 1 | Out-String).Trim()
}

# Git >= 2.40
$v = Get-Version git '--version'
if (-not $v) { Ko "Git absent" }
elseif ($v -match '(\d+)\.(\d+)' -and ([int]$Matches[1] -gt 2 -or ([int]$Matches[1] -eq 2 -and [int]$Matches[2] -ge 40))) { Ok $v }
else { Ko "$v (>= 2.40 requis)" }

# Git Bash (livré avec Git for Windows ; on évite `bash` seul, qui peut être celui de WSL)
$g = Get-Command git -ErrorAction SilentlyContinue
if ($g) {
    $bashGit = Join-Path (Split-Path (Split-Path $g.Source)) 'bin\bash.exe'
    if (Test-Path $bashGit) { Ok "Git Bash : $bashGit" } else { Ko "Git Bash introuvable (réinstaller Git for Windows)" }
}

# Visual Studio Code (non bloquant : tout autre éditeur convient)
if (Get-Command code -ErrorAction SilentlyContinue) { Ok "VS Code : $((code --version 2>&1 | Select-Object -First 1))" }
else { Warn "VS Code absent ou 'code' hors PATH (rouvrir le terminal après l'installation)" }

# Java 21
$v = Get-Version java '-version'
if (-not $v) { Ko "Java absent (JDK 21 requis)" }
elseif ($v -match '"21\.') { Ok "Java : $v" }
else { Ko "Java : $v (version 21 requise)" }

# Maven 3.9 (facultatif si on utilise le conteneur Maven)
$v = Get-Version mvn '-v'
if (-not $v) { Warn "Maven absent : utiliser le conteneur maven:3.9-eclipse-temurin-21 (voir guide-installation.md)" }
elseif ($v -match 'Apache Maven 3\.(\d+)' -and [int]$Matches[1] -ge 9) { Ok $v }
else { Warn "$v (3.9+ recommandé)" }

# Docker + Compose + démon
$v = Get-Version docker '--version'
if (-not $v) { Ko "Docker absent" }
else {
    Ok $v
    docker info *> $null
    if ($LASTEXITCODE -ne 0) { Ko "Le démon Docker ne répond pas (lancer Docker Desktop)" }
    else {
        Ok "Démon Docker joignable"
        $c = (docker compose version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) { Ok $c } else { Ko "Docker Compose v2 absent" }
        $mem = docker info --format '{{.MemTotal}}' 2>$null
        if ($mem) {
            $go = [math]::Round([double]$mem / 1GB, 1)
            if ($go -ge 7) { Ok "Mémoire allouée à Docker : $go Go" }
            else { Ko "Mémoire allouée à Docker : $go Go (8 Go minimum, 16 Go recommandés : Nexus + SonarQube + GitLab CE). Réglage : %UserProfile%\.wslconfig ([wsl2] memory=8GB) puis 'wsl --shutdown'" }
        }
    }
}

# Mémoire physique
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
if ($ram -ge 16) { Ok "RAM du poste : $ram Go" } else { Warn "RAM du poste : $ram Go (16 Go conseillés)" }

# Ports du lab
$ports = 5432, 8080, 8081, 8083, 8090, 8091, 8929, 9000
foreach ($p in $ports) {
    $occ = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    if ($occ) { Warn "Port $p déjà utilisé (PID $($occ[0].OwningProcess))" } else { Ok "Port $p libre" }
}

# Accès sortant aux dépôts
foreach ($u in 'https://repo.maven.apache.org/maven2/', 'https://registry-1.docker.io/v2/') {
    try { Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 8 -Method Head | Out-Null; Ok "Accès à $u" }
    catch { if ($_.Exception.Response) { Ok "Accès à $u" } else { Warn "Pas d'accès à $u (proxy ?)" } }
}

Write-Host ""
if ($script:echecs -eq 0) { Write-Host "Poste prêt." -ForegroundColor Green; exit 0 }
Write-Host "$($script:echecs) élément(s) bloquant(s). Voir installer-outils.ps1." -ForegroundColor Red; exit 1
