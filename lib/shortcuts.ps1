# Creates shortcut for the app in the start menu
function create_startmenu_shortcuts($manifest, $dir, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
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
    if ($IsMacOS) {
        return "$scoopdir/menu/Scoop Apps"
    } elseif ($IsLinux) {
        return "$env:HOME/.local/share/applications"
    }
    if ($global) {
        $startmenu = 'CommonStartMenu'
    } else {
        $startmenu = 'StartMenu'
    }
    return Convert-Path (ensure ([System.IO.Path]::Combine([Environment]::GetFolderPath($startmenu), 'Programs', 'Scoop Apps')))
}

function startmenu_shortcut([System.IO.FileInfo] $target, $shortcutName, $arguments, [System.IO.FileInfo]$icon, $global) {
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

    if ($IsMacOS) {
        $app = "$scoop_startmenu_folder/$shortcutName.app"
        $wine = Get-Command wine64 | Select-Object -ExpandProperty Definition
        $prefix = "$env:HOME/.wine"
        $exeName = $target.Name
        $exe = "$app/Contents/MacOS/$exeName"
        $_ = ensure "$app/Contents/MacOS/"
        $fullName = $target.FullName
        $script = @"
#!/bin/sh
WINEPREFIX="$prefix" $wine "$fullName" "`$@" &
"@
        $script | %{ $_.Replace("`r`n","`n") } | Out-File -FilePath $exe
        chmod +x $exe
        if ( -not $icon) {
            $icon = $target
        }
        $icns = "$app/Contents/Resources/$shortcutName.icns"
        $_ = ensure "$app/Contents/Resources/"
        $icoFullName = $icon.FullName 
        & $scoopdir/apps/scoop/current/supporting/ico2icns/ico2icns.sh $icoFullName $icns
        $bundleIdentifier = ( "scoop.wine.launcher.$shortcutName" | tr -C -d "A-Za-z0-9-." )
        $info = "$app/Contents/Info.plist"
        $json = @"
{
  "CFBundleName" : "$shortcutName",
  "CFBundleDisplayName" : "$shortcutName",
  "CFBundleIdentifier" : "$bundleIdentifier",
  "CFBundlePackageType" : "APPL",
  "CFBundleSignature" : "????",
  "CFBundleExecutable" : "$exeName",
  "CFBundleIconFile" : "$shortcutName.icns",
}
"@
        $json | plutil -convert xml1 -o $info -
    } elseif ($IsLinux) {
        $desktop = "$scoop_startmenu_folder/scoop.wine.$shortcutName.desktop"
        $fullName = $target.FullName
        if ( -not $icon) {
            $icon = $target
        }
        $icoFullName = $icon.FullName 
        $png = "$env:HOME/.local/share/icons/scoop.wine.$shortcutName.png"
        $_ = ensure "$env:HOME/.local/share/icons"
        & $scoopdir/apps/scoop/current/supporting/ico2icns/ico2png.sh $icoFullName $png
        $ini = @"
[Desktop Entry]
Type=Application
Name=$shortcutName
Exec=wine64 "$fullName"
Icon=scoop.wine.$shortcutName.png
"@
        $ini | out-file $desktop
        chmod +x "$desktop"
    } else {
    $wsShell = New-Object -ComObject WScript.Shell
    $wsShell = $wsShell.CreateShortcut("$scoop_startmenu_folder\$shortcutName.lnk")
    $wsShell.TargetPath = $target.FullName
    $wsShell.WorkingDirectory = $target.DirectoryName
    if ($arguments) {
        $wsShell.Arguments = $arguments
    }
    if($icon -and $icon.Exists) {
        $wsShell.IconLocation = $icon.FullName
    }
    $wsShell.Save()
    }
    write-host "Creating shortcut for $shortcutName ($(fname $target))"
}

# Removes the Startmenu shortcut if it exists
function rm_startmenu_shortcuts($manifest, $global, $arch) {
    $shortcuts = @(arch_specific 'shortcuts' $manifest $arch)
    $shortcuts | Where-Object { $_ -ne $null } | ForEach-Object {
        $name = $_.item(1)
        if ($IsMacOS) {
        $shortcut = "$(shortcut_folder $global)/$name.app"
        write-host "Removing shortcut $(friendly_path $shortcut)"
        if(Test-Path -Path $shortcut) {
             Remove-Item -Recurse $shortcut
        }
        } elseif ($IsLinux) {
        $shortcut = "$(shortcut_folder $global)/scoop.wine.$shortcutName.desktop"
        write-host "Removing shortcut $(friendly_path $shortcut)"
        if(Test-Path -Path $shortcut) {
             Remove-Item -Recurse $shortcut
        }
        $png = "$env:HOME/.local/share/icons/scoop.wine.$shortcutName.png"
        write-host "Removing icon $(friendly_path $png)"
        if(Test-Path -Path $png) {
             Remove-Item -Recurse $png
        }
        } else {
        $shortcut = "$(shortcut_folder $global)\$name.lnk"
        write-host "Removing shortcut $(friendly_path $shortcut)"
        if(Test-Path -Path $shortcut) {
             Remove-Item $shortcut
        }
        }
    }
}
