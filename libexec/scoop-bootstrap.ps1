# Summary: Setup minimal manifests for 7zip and git

. "$PSScriptRoot\..\lib\buckets.ps1"

$MainPath = (Find-BucketDirectory -Name "main" -Root)
$BucketPath = Join-Path -Path $MainPath -ChildPath "bucket"
New-Item -ItemType Directory -Path $BucketPath -Force | Out-Null
$ScriptsPath = Join-Path -Path $MainPath -ChildPath "scripts"
New-Item -ItemType Directory -Path $ScriptsPath -Force | Out-Null

function Get-RemoteFile() {
    param (
        [Parameter(Mandatory)] $Url,
        [Parameter(Mandatory)] $DestinationPath
    )
    if ($IsMacOS -Or $IsLinux) {
        curl --output-dir $DestinationPath -O -C - -L -# $Url
    } else {
        curl.exe --output-dir $DestinationPath -O -C - -L -# $Url
    }
}

Get-RemoteFile "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/git.json" $BucketPath
Get-RemoteFile  "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/7zip.json" $BucketPath
Get-RemoteFile  "https://raw.githubusercontent.com/ScoopInstaller/Main/master/scripts/install-context.reg" $ScriptsPath
Get-RemoteFile  "https://raw.githubusercontent.com/ScoopInstaller/Main/master/scripyts/uninstall-context.reg" $ScriptsPath
