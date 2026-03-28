$ChocoPath = $env:ChocolateyInstall

$PackagesPath = if ($ChocoPath) { Join-Path $env:ChocolateyInstall "lib" } else { "C:\ProgramData\chocolatey\lib\" }
if (-not (Test-Path $PackagesPath)) {
    Read-Host "Chocolatey is installed ?"
    return
}

$packagesRaw = Get-ChildItem $PackagesPath -Recurse  *.nuspec | select Fullname,Name
if ($packagesRaw.Count -eq 0) {
    Write-Host "No packages found"
    return
}

$packages = New-Object System.Collections.ArrayList
foreach($p in $packagesRaw){
    [XML]$xml=Get-Content $p.Fullname

    $pack = New-Object -TypeName psobject

    $pack | Add-Member -MemberType NoteProperty -Name "Name" -Value $xml.package.metadata.id
    $pack | Add-Member -MemberType NoteProperty -Name "Path" -Value $p.FullName
    $pack | Add-Member -MemberType NoteProperty -Name "Version" -Value $xml.package.metadata.version
    $pack | Add-Member -MemberType NoteProperty -Name "Dependencies" -Value (New-Object System.Collections.ArrayList)

    $dependencies = $xml.package.metadata.dependencies.dependency
    foreach($d in $dependencies){
            
        $dep = New-Object -TypeName psobject

        $dep | Add-Member -MemberType NoteProperty -Name "Name" -Value $d.id
        $dep | Add-Member -MemberType NoteProperty -Name "Version" -Value $d.version

        $pack.Dependencies.Add($dep) > $null
    }

    $packages.Add($pack) > $null
}



foreach ($p in $packages) {
    if ($p.Dependencies.Count -eq 0) { continue }
    $p | Select-Object Name, Version

    foreach ($d in $p.Dependencies) {
        $dep = $d | Select-Object Name, Version
        $dep.Name = "    $($dep.Name)"
        $dep
    }
    "--------------------------------------------------------------"
}
