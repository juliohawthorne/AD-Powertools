Import-Module ActiveDirectory

# command line arguments
$SinceLoginDays = $args[0]
$SinceCreatedDays = $args[1]
$OutPath = $args[2]

if ($OutPath -eq $null) {
    $OutPath = Read-Host 'Enter the desired path of the desired output file (.csv)'
}

if ($SinceLoginDays -eq $null) {
    $SinceLoginDays = Read-Host "Specify the range of time in days since the last login"
}

if ($SinceCreatedDays -eq $null) {
    $SinceCreatedDays = Read-Host "Specify the range of time in days since account creation"
}

function Get-DisabledUsers {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
        Position=0,
        ParameterSetName="Date")]
        [int]$LastLoginRange,

        [Parameter(Mandatory=$true,
        Position=1,
        ParameterSetName="Date")]
        [Alias("CreatedRange")]
        [int]$CreatedTimeRange
    )

    get-aduser -Filter "enabled -eq '$false'" -Properties * | Where {$_.DistinguishedName -like "*Terminations*"} |
        Where {$_.LastLogonDate -lt $((Get-Date).AddDays(-$LastLoginRange)) -or $_.LastLogonDate -eq ""} |
        Where {$_.whenCreated -gt $((Get-Date).AddDays(-$CreatedTimeRange))} |
        select-object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l, enabled, LastLogonDate, DistinguishedName

}

function Test-OutFile {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [Alias('Path')]
        [string]$File
    )

    if (Test-Path -Path "$File") {
        try {
            Remove-Item -Path "$File" -ErrorAction Stop
        } catch [System.IO.IOException] {
            Write-Host "The output file is currently open in another process. Please close the file and try again."
        } catch {
            Write-Host "There was an unknown error checking the output filepath. Please check the filepath and try again"
        }
        if (Test-Path -Path "$File") {
            return $true
        } else {
            return $false
        }
    } else {
        return $false
    }
}

# Trim double-quotes off of path to output .csv
$OutFile = $OutPath.Trim('"')

$OutFileExists = Test-OutFile -Path $OutFile

if ($OutFileExists -eq $false) {
    $disabled = Get-DisabledUsers -LastLogin $SinceLoginDays -CreatedRange $SinceCreatedDays
    $disabled |
        Export-Csv -NoTypeInformation $OutFile
}