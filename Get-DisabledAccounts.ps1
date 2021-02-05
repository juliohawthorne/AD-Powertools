Import-Module ActiveDirectory

# outfile path arguments
$OutFile = $args[0]
$Days = $args[1]

if ($OutFile -eq $null) {
    $OutFile = Read-Host 'Enter the desired path of the desired output file (.csv)'
}

if ($Days -eq $null) {
    $Days = Read-Host 'Enter the number of days to search for disabled AD Accounts'
}

function Get-DisabledUsers {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [int]$TimeRange
    )

    get-aduser -Filter "enabled -eq '$false'" -Properties * | Where {$_.whenCreated -gt $((Get-Date).AddDays(-$TimeRange))} | select-object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l, enabled

}

$disabled = Get-DisabledUsers -TimeRange $Days

$disabled | Export-Csv -NoTypeInformation $OutFile.Trim('"')