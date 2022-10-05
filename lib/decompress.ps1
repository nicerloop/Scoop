function Expand-7zipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [ValidateSet('All', 'Skip', 'Rename')]
        [String]
        $Overwrite,
        [Switch]
        $Removal
    )
    if ((get_config 7ZIPEXTRACT_USE_EXTERNAL)) {
        try {
            $7zPath = (Get-Command '7z' -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        } catch [System.Management.Automation.CommandNotFoundException] {
            abort "`nCannot find external 7-Zip (7z.exe) while '7ZIPEXTRACT_USE_EXTERNAL' is 'true'!`nRun 'scoop config 7ZIPEXTRACT_USE_EXTERNAL false' or install 7-Zip manually and try again."
        }
    } else {
        $7zPath = Get-HelperPath -Helper 7zip
    }
    $LogPath = Join-Path $(Split-Path $Path) "7zip.log"
    if ($is_wsl) {
        $Path = win_path $Path
        $DestinationPath = win_path $DestinationPath
    }
    $ArgList = @('x', $Path, "-o$DestinationPath", '-y')
    $IsTar = ((strip_ext $Path) -match '\.tar$') -or ($Path -match '\.t[abgpx]z2?$')
    if (!$IsTar -and $ExtractDir) {
        $ArgList += "-ir!$ExtractDir\*"
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    switch ($Overwrite) {
        'All' { $ArgList += '-aoa' }
        'Skip' { $ArgList += '-aos' }
        'Rename' { $ArgList += '-aou' }
    }
    $Status = Invoke-ExternalCommand $7zPath $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if ($is_wsl) {
        $DestinationPath = wslpath -u $DestinationPath
    }
    if (!$IsTar -and $ExtractDir) {
        movedir $(Join-Path $DestinationPath $ExtractDir) $DestinationPath | Out-Null
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($IsTar) {
        # Check for tar
        $Status = Invoke-ExternalCommand $7zPath @('l', $Path) -LogPath $LogPath
        if ($Status) {
            # get inner tar file name
            $TarFile = (Select-String -Path $LogPath -Pattern '[^ ]*tar$').Matches.Value
            Expand-7zipArchive -Path "$DestinationPath\$TarFile" -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal
        } else {
            abort "Failed to list files in $Path.`nNot a 7-Zip supported archive file."
        }
    }
    if ($Removal) {
        if ($is_wsl) {
            $Path = wslpath -u $Path
        }
        # Remove original archive file
        if (($Path -replace '.*\.([^\.]*)$', '$1') -eq '001') {
            # Remove splited 7-zip archive parts
            Get-ChildItem "$($Path -replace '\.[^\.]*$', '').???" | Remove-Item -Force
        } elseif (($Path -replace '.*\.part(\d+)\.rar$', '$1')[-1] -eq '1') {
            # Remove splitted RAR archive parts
            Get-ChildItem "$($Path -replace '\.part(\d+)\.rar$', '').part*.rar" | Remove-Item -Force
        } else {
            Remove-Item $Path -Force
        }
    }
}

function Expand-ZstdArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $ZstdPath = Get-HelperPath -Helper Zstd
    $LogPath = Join-Path (Split-Path $Path) 'zstd.log'
    $DestinationPath = $DestinationPath.TrimEnd('\')
    ensure $DestinationPath | Out-Null
    $ArgList = @('-d', $Path, '--output-dir-flat', $DestinationPath, '-f', '-v')

    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    if ($Removal) {
        # Remove original archive file
        $ArgList += '--rm'
    }
    $Status = Invoke-ExternalCommand $ZstdPath $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    $IsTar = (strip_ext $Path) -match '\.tar$'
    if (!$IsTar -and $ExtractDir) {
        movedir (Join-Path $DestinationPath $ExtractDir) $DestinationPath | Out-Null
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($IsTar) {
        # Check for tar
        $TarFile = Join-Path $DestinationPath (strip_ext (fname $Path))
        Expand-7zipArchive -Path $TarFile -DestinationPath $DestinationPath -ExtractDir $ExtractDir -Removal
    }
}

function Expand-MsiArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $DestinationPath = $DestinationPath.TrimEnd('\')
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = Join-Path $DestinationPath "_tmp"
    }
    if ((get_config MSIEXTRACT_USE_LESSMSI)) {
        $MsiPath = Get-HelperPath -Helper Lessmsi
        $ArgList = @('x', $Path, "$DestinationPath\")
    } else {
        $MsiPath = 'msiexec.exe'
        $ArgList = @('/a', "`"$Path`"", '/qn', "TARGETDIR=`"$DestinationPath\SourceDir`"")
    }
    $LogPath = Join-Path $(Split-Path $Path) "msi.log"
    if ($is_wsl) {
        $MsiPath = 'msiexec.exe'
        $ArgList = @('/a', "`"$(win_path $Path)`"", '/qn', "TARGETDIR=`"$(win_path $DestinationPath)\SourceDir`"")
        $LogPath = win_path $LogPath
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand $MsiPath $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if ($ExtractDir -and (Test-Path $(Join-Path $DestinationPath "SourceDir"))) {
        movedir $(Join-Path $DestinationPath "SourceDir" $ExtractDir) $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    } elseif ($ExtractDir) {
        movedir $(Join-Path $DestinationPath $ExtractDir) $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    } elseif (Test-Path $(Join-Path $DestinationPath "SourceDir")) {
        movedir $(Join-Path $DestinationPath "SourceDir") $DestinationPath | Out-Null
    }
    if (($DestinationPath -ne (Split-Path $Path)) -and (Test-Path $(Join-Path $DestinationPath $(fname $Path)))) {
        Remove-Item $(Join-Path $DestinationPath $(fname $Path)) -Force
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-InnoArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $LogPath = Join-Path $(Split-Path $Path) "innounp.log"
    $ArgList = @('-x', "-d$DestinationPath", $Path, '-y')
    switch -Regex ($ExtractDir) {
        '^[^{].*' { $ArgList += "-c{app}\$ExtractDir" }
        '^{.*' { $ArgList += "-c$ExtractDir" }
        Default { $ArgList += '-c{app}' }
    }
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Innounp) $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-ZipArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [String]
        $ExtractDir,
        [Switch]
        $Removal
    )
    if ($ExtractDir) {
        $OriDestinationPath = $DestinationPath
        $DestinationPath = Join-Path $DestinationPath "_tmp"
    }
    Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
    if ($ExtractDir) {
        movedir $(Join-Path $DestinationPath $ExtractDir) $OriDestinationPath | Out-Null
        Remove-Item $DestinationPath -Recurse -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}

function Expand-DarkArchive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [String]
        $Path,
        [Parameter(Position = 1)]
        [String]
        $DestinationPath = (Split-Path $Path),
        [Parameter(ValueFromRemainingArguments = $true)]
        [String]
        $Switches,
        [Switch]
        $Removal
    )
    $LogPath = Join-Path $(Split-Path $Path) "dark.log"
    $Path = win_path $Path
    $DestinationPath = win_path $DestinationPath
    $LogPath = win_path $LogPath
    $ArgList = @('-nologo', '-x', $DestinationPath, $Path)
    if ($Switches) {
        $ArgList += (-split $Switches)
    }
    $Status = Invoke-ExternalCommand (Get-HelperPath -Helper Dark) $ArgList -LogPath $LogPath
    if (!$Status) {
        abort "Failed to extract files from $Path.`nLog file:`n  $(friendly_path $LogPath)`n$(new_issue_msg $app $bucket 'decompress error')"
    }
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
    }
    if ($Removal) {
        # Remove original archive file
        Remove-Item $Path -Force
    }
}
