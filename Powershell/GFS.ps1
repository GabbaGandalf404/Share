
<#=======================================
                Modules                               
=======================================#>
$MyModulePath = "C:\Program Files\Veeam\Backup and Replication\Console\"
$env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$MyModulePath"
if ($Modules = Get-Module -ListAvailable -Name Veeam.Backup.PowerShell) {
    try {
        $Modules | Import-Module -WarningAction SilentlyContinue
    }catch {
        throw "Failed to load Veeam Modules"
        exit $difderror
    }
}
##################################################################
#                     Variablen 
##################################################################
# Hole alle aktiven Backup Jobs, die laufen
$jobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object { 
    $_.IsScheduleEnabled -eq $true 
}
[int]$minRetention = 14 # VorhalteZeit darf nicht unter diesen Wert 
[int]$minGfsWeekly = 2 # Gfsweekly darf nicht unter diesen wert 
$WarningCount = 0
$FinalResultOK = @() # Object für Ergebniss 
$FinalResultNotOK = @() # Object für Ergebniss

##################################################################
#                     Überprüfung der Jobs 
##################################################################
foreach ($job in $jobs) {
    ##################################################################
    #                     Variablen 
    ##################################################################
    $tempObj = "" | Select-Object Name , VorhalteZeit , GfsWeekly
    $Name = $job.Name
    $isGfsActive = $job.Options.GfsPolicy.IsEnabled
    [int]$VorhalteZeit = $job.BackupStorageOptions.RetainDaysToKeep
    # Checkt ob Gfs aktiviert ist 
    if($isGfsActive -eq $false) {
        $GfsWeekly = "deaktiviert"
    }else{
        $GfsWeekly = $job.Options.GfsPolicy.Weekly.KeepBackupsForNumberOfWeeks
    }
    #Erste Bedingung Vorhalte Zeit darf nicht unter 14 Tage wenn Gfs nicht Aktiv ist 
    [bool]$bedingung = ($VorhalteZeit -lt $minRetention -and ($isGfsActive -eq $false)) 
    #Zweite Bedingung Vorhaltezeit Zeit darf nicht kleiner als 14 Tage sein ind GFSweekly darf nicht unter 2 
    [bool]$bedingung2 = (($isGfsActive -eq $true) -and (($GfsWeekly -lt $minGfsWeekly) -and ($VorhalteZeit -lt $minRetention))) 
    #es werden nur Backups jobs überprüft
    ##################################################################
    #                     Überprüfung
    ##################################################################
    #Überprüft nur Backup Jobs 
    if ($job.JobType -eq 'Backup') {
        #Wenn Gfs nicht aktiv ist dann wird es ignoriert weil Gfs weekly trotzdem einen Standert Wert haben kann
        # Also ohne Gfs darf Vorhalte zeit nicht unter 14 tage
        if($bedingung  -or $bedingung2){
            $WarningCount = $WarningCount + 1
            $tempObj.Name = $Name
            $tempObj.VorhalteZeit = "$($VorhalteZeit) Tage"
            $tempObj.GfsWeekly = $GfsWeekly
            $FinalResultNotOK += $tempObj
        } else{
            $tempObj.Name = $Name 
            $tempObj.VorhalteZeit = "$($VorhalteZeit) Tage"
            $tempObj.GfsWeekly = $GfsWeekly         
            $FinalResultOK += $tempObj
        }

    }
}


##################################################################
#                   Ausgabe auf Console 
##################################################################

if ($FinalResultNotOK.Count -gt 0 ) {
    Write-Output "Vorhaltezeiten sind nicht richtig eingestellt bei :"
    Write-Output "-----------------------------------------------"
    # Ausgabe jedes Elements aus dem NotOK Array, jeweils in einer neuen Zeile
    $FinalResultNotOK | ForEach-Object {
        $output = ""
        $Output  = "Job: $($_.Name) | VorhalteZeit: $($_.VorhalteZeit)"
        if ( !($_.GfsWeekly -like "deaktiviert")) {
            $Output += " | GfsWeekly: $($_.GfsWeekly)"        
        }
        $output
    }
    Write-Output "-----------------------------------------------"
}
    # Wenn es auch OK Ergebnisse gibt, dann auch diese ausgeben
if($FinalResultOK.Count -gt 0) {
    Write-Output "Gfs und VorhalteZeit sind richtig Eingestellt bei:"
    Write-Output "-----------------------------------------------"
    $FinalResultOK | ForEach-Object {
        $output = ""
        $Output  = "Job: $($_.Name) | VorhalteZeit: $($_.VorhalteZeit)"
        if ( !($_.GfsWeekly -like "deaktiviert")) {
            $Output += " | GfsWeekly: $($_.GfsWeekly)"        
        }
        $output
    }
}
