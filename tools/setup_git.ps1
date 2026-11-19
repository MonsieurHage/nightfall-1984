# Préparation locale d'un dépôt Git (AUCUN push / AUCUNE connexion distante).
# Git doit etre installe et accessible dans le PATH, ou renseigner $GitExe.
param(
    [string]$GitExe = "git",
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$CommitMessage = "Nightfall 1984 - Protocole Skynet : version initiale"
)

$ErrorActionPreference = "Stop"

# Verifier la presence de Git
try { & $GitExe --version | Out-Null }
catch { throw "Git introuvable ($GitExe). Installer Git for Windows puis relancer ce script." }

Set-Location $ProjectDir

if (-not (Test-Path ".git")) {
    & $GitExe init -b main
} else {
    Write-Host "Depot deja initialise."
}
& $GitExe config user.name "Nightfall Dev"
& $GitExe config user.email "nightfall@example.local"

& $GitExe add -A
& $GitExe status --short
& $GitExe commit -m $CommitMessage

Write-Host "`nDepot LOCAL pret. Aucune remote configuree :"
& $GitExe remote -v
Write-Host "Pour publier plus tard (sur demande explicite) :"
Write-Host "  git remote add origin <URL> ; git push -u origin main"
