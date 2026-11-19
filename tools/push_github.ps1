# Pousse le projet vers GitHub avec le token OAuth deja stocke dans le
# gestionnaire d'identifiants Windows (jamais ecrit en clair dans le depot).
# A utiliser une fois Git installe.
$ErrorActionPreference = "Stop"

$src = @'
using System; using System.Runtime.InteropServices;
public static class CredManPush {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct CREDENTIAL {
        public uint Flags; public uint Type; public string TargetName; public string Comment;
        public long LastWritten; public uint CredentialBlobSize; public IntPtr CredentialBlob;
        public uint Persist; public uint AttributeCount; public IntPtr Attributes;
        public string TargetAlias; public string UserName; }
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredRead(string t,uint y,uint f,out IntPtr c);
    [DllImport("advapi32.dll")] public static extern void CredFree(IntPtr b);
    public static string Get(string t){ IntPtr p; if(!CredRead(t,1,0,out p)) return $null;
        try { var c=(CREDENTIAL)Marshal.PtrToStructure(p,typeof(CREDENTIAL));
              return Marshal.PtrToStringUni(c.CredentialBlob,(int)(c.CredentialBlobSize/2)); }
        finally { CredFree(p); } }
}
'@
Add-Type -TypeDefinition $src -ErrorAction SilentlyContinue

$proj = Split-Path -Parent $PSScriptRoot
Set-Location $proj

$token = [CredManPush]::Get('git:https://github.com')
if (-not $token) { throw "Token GitHub introuvable dans le gestionnaire d'identifiants Windows." }

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

if (-not (Test-Path '.git')) { git init -b main }
git config user.name "Nightfall Dev"
git config user.email "nightfall@example.local"

$remote = "https://MonsieurHage:$token@github.com/MonsieurHage/nightfall-1984.git"
if (git remote get-url origin 2>$null) { git remote set-url origin $remote }
else { git remote add origin $remote }

git add -A
git commit -m "Nightfall 1984 - Protocole Skynet : version initiale" 2>$null
git branch -M main
git push -u origin main --force

# Ne pas conserver le token dans la configuration locale du depot
git remote set-url origin "https://github.com/MonsieurHage/nightfall-1984.git"

Write-Host "DEPLOY TERMINE : https://github.com/MonsieurHage/nightfall-1984"
