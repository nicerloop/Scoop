. "$PSScriptRoot\..\lib\buckets.ps1"

$BucketPath = Join-Path (Find-BucketDirectory "main") "bucket"
New-Item -ItemType Directory -Path $BucketPath
Set-Location $BucketPath
curl.exe -O "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/git.json"
curl.exe -O "https://raw.githubusercontent.com/ScoopInstaller/Main/master/bucket/7zip.json"
