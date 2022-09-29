# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
        if ($is_wsl) {
            $_.item(0) = $_.item(0) -Replace '\\', '/'
            if($_.length -ge 4) {
                $_.item(3) = $_.item(3) -Replace '\\', '/'
            }
        }
        $target = [System.IO.Path]::Combine($dir, $_.item(0))
        $target = New-Object System.IO.FileInfo($target)
        $name = $_.item(1)
        $arguments = ""
        $icon = $null
        if($_.length -ge 3) {
            $arguments = $_.item(2)
        }
        if($_.length -ge 4) {
            $icon = [System.IO.Path]::Combine($dir, $_.item(3))
            $icon = New-Object System.IO.FileInfo($icon)
        }
        $arguments = (substitute $arguments @{ '$dir' = $dir; '$original_dir' = $original_dir; '$persist_dir' = $persist_dir})
        startmenu_shortcut $target $name $arguments $icon $global
    }
}

function shortcut_folder($global) {
    if ($global) {
        $startmenu = 'CommonStartMenu'
    } else {
        $startmenu = 'StartMenu'
    }
    $menufolder = [Environment]::GetFolderPath($startmenu)
    if ($is_wsl) {
        $menufolder = wslpath -u $(powershell.exe -c "[Environment]::GetFolderPath(`'$startmenu`')")
    }
    return Convert-Path (ensure ([System.IO.Path]::Combine($menufolder, 'Programs', 'Scoop Apps')))
}

function startmenu_shortcut([System.IO.FileInfo] $target, $shortcutName, $arguments, [System.IO.FileInfo]$icon, $global) {
    Write-host startmenu_shortcut $target, $shortcutName, $arguments, $icon, $global
    if(!$target.Exists) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find $target"
        return
    }
    if($icon -and !$icon.Exists) {
        Write-Host -f DarkRed "Creating shortcut for $shortcutName ($(fname $target)) failed: Couldn't find icon $icon"
        return
    }

    $scoop_startmenu_folder = shortcut_folder $global
    $subdirectory = [System.IO.Path]::GetDirectoryName($shortcutName)
    if ($subdirectory) {
        $subdirectory = ensure $([System.IO.Path]::Combine($scoop_startmenu_folder, $subdirectory))
    }

    if ($is_wsl) {
        write-host "Creating shortcut for $shortcutName ($(fname $target))"
        $scoop_startmenu_folder = win_path $scoop_startmenu_folder
        $targetPath = win_path $target.FullName
        $WorkingDirectory = win_path $target.DirectoryName
        $command = "`$wsShell = New-Object -ComObject WScript.Shell"
        $command += ";`n`r"
        $command += "`$wsShell = `$wsShell.CreateShortcut(`'$scoop_startmenu_folder\$shortcutName.lnk`')"
        $command += ";`n`r"
        $command += "`$wsShell.TargetPath = `'$targetPath`'"
        $command += ";`n`r"
        $command += "`$wsShell.WorkingDirectory = `'$WorkingDirectory`'"
        if ($arguments) {
            $command += ";`n`r"
            $command += "`$wsShell.Arguments = `'$arguments`'"
        }
        if($icon -and $icon.Exists) {
            $command += ";`n`r"
            $iconFullName = $icon.FullName
            $command += "`$wsShell.IconLocation = `'$iconFullName`'"
        }
        $command += ";`n`r"
        $command += "`$wsShell.Save()"
        $command += ";`n`r"
        powershell.exe -c "& { `$( $command ) }"
        return
    }

    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut($(Join-Path $scoop_startmenu_folder "$shortcutName.lnk"))
    $wsShell.TargetPath = $target.FullName
    $wsShell.WorkingDirectory = $target.DirectoryName
    if ($arguments) {
        $wsShell.Arguments = $arguments
    }
    if($icon -and $icon.Exists) {
        $wsShell.IconLocation = $icon.FullName
    }
    $wsShell.Save()
    write-host "Creating shortcut for $shortcutName ($(fname $target))"
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
        $name = $_.item(1)
        $shortcut = Join-Path $(shortcut_folder $global) "$name.lnk"
        write-host "Removing shortcut $(friendly_path $shortcut)"
        if(Test-Path -Path $shortcut) {
             Remove-Item $shortcut
        }
    }
}
