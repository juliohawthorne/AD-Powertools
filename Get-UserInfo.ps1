Import-Module ActiveDirectory

clear

# Search AD using employeeid
function Get-UserByEid {
    [CmdletBinding()]
    param(
        $EmployeeId
    )
    Get-ADUser -Filter "employeeId -eq '$EmployeeId'" -Properties *
}

# Search AD using user's name
function Get-UserByName {
    [CmdletBinding()]
    param(
        $Name
    )
    Get-ADUser -Filter "Name -like '$Name'" -Properties *
}

# search AD using user's emailAddress
function Get-UserByEmail {
    [CmdletBinding()]
    param(
        $Email
    )
    Get-ADUser -Filter "emailAddress -like '$Email'" -Properties *
}

# Removes special characters from string to avoid parsing errors
# Source: https://github.com/lazywinadmin/PowerShell/blob/master/TOOL-Remove-StringSpecialCharacter/Remove-StringSpecialCharacter.ps1
function Remove-StringSpecialCharacter {
    <#
.SYNOPSIS
    This function will remove the special character from a string.
.DESCRIPTION
    This function will remove the special character from a string.
    I'm using Unicode Regular Expressions with the following categories
    \p{L} : any kind of letter from any language.
    \p{Nd} : a digit zero through nine in any script except ideographic
    http://www.regular-expressions.info/unicode.html
    http://unicode.org/reports/tr18/
.PARAMETER String
    Specifies the String on which the special character will be removed
.PARAMETER SpecialCharacterToKeep
    Specifies the special character to keep in the output
.EXAMPLE
    Remove-StringSpecialCharacter -String "^&*@wow*(&(*&@"
    wow
.EXAMPLE
    Remove-StringSpecialCharacter -String "wow#@!`~)(\|?/}{-_=+*"
    wow
.EXAMPLE
    Remove-StringSpecialCharacter -String "wow#@!`~)(\|?/}{-_=+*" -SpecialCharacterToKeep "*","_","-"
    wow-_*
.NOTES
    Francois-Xavier Cat
    @lazywinadmin
    lazywinadmin.com
    github.com/lazywinadmin
#>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Text')]
        [System.String[]]$String,

        [Alias("Keep")]
        #[ValidateNotNullOrEmpty()]
        [String[]]$SpecialCharacterToKeep
    )
    PROCESS {
        try {
            IF ($PSBoundParameters["SpecialCharacterToKeep"]) {
                $Regex = "[^\p{L}\p{Nd}"
                Foreach ($Character in $SpecialCharacterToKeep) {
                    IF ($Character -eq "-") {
                        $Regex += "-"
                    }
                    else {
                        $Regex += [Regex]::Escape($Character)
                    }
                    #$Regex += "/$character"
                }

                $Regex += "]+"
            } #IF($PSBoundParameters["SpecialCharacterToKeep"])
            ELSE { $Regex = "[^\p{L}\p{Nd}]+" }

            FOREACH ($Str in $string) {
                Write-Verbose -Message "Original String: $Str"
                $Str -replace $regex, ""
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    } #PROCESS
}


# input|outfile path arguments
$type = $args[0]
$list = $args[1]
$export = $args[2]

# Search parameter type matching
$types = @(
    '*name'
    'email*'
    'employeeId'
)

# Receive type from stdin
while ($type -eq $null -Or $type -eq "") {
    $type = Read-Host 'Enter the search type (email, name, or employeeid)'
}

# Output header values based on type match or exit if match unsuccessful
if ($type -like $types[0]) {
    Write-Host "The input .csv must ONLY contain the following case-sensitive headers: name"
    $type = $types[0]
} elseif ($type -like $types[1]) {
    Write-Host "The input .csv must ONLY contain the following case-sensitive headers: emailAddress"
    $type = $types[1]
} elseif ($type -like $types[2]) {
    Write-Host "The input .csv must ONLY contain the following case-sensitive headers: employeeId"
    $type = $types[2]
} else {
    Write-Host "Search type not recognized`r`nValid search types: name, email, employeeid"
    return
}

# Receive input and output files from stdin
if ($list -eq $null) {
    $list = Read-Host 'Enter the path to the input .csv file (e.g. C:\userlist.csv )'
}

if ($export -eq $null) {
    Write-Output "The output '.csv' file will include the following information: name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title"
    $export = Read-Host 'Enter the path to the desired output .csv file'
}

# Trim double quotes from filepath variables, fixes parsing errors
$userlist = $list.Trim('"')
$outfile = $export.Trim('"')

# Remove the output filie if it exists
if (Test-Path -Path "$outfile") {
    Remove-Item -Path "$outfile"
}

# Search AD for each row of the input file based on type and output results to outfile or write error if previous type matching failed
if ($type -eq $types[0]) {
    Import-Csv -Path "$userlist" | ForEach-Object {
    $firstname = Remove-StringSpecialCharacter -String "$($_.givenName)"
    $lastname = Remove-StringSpecialCharacter -String "$($_.surname)"
    Get-UserByName -Name "$firstname*$lastname"
    } | Select-Object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l | Export-Csv "$outfile" -NoTypeInformation
} elseif ($type -eq $types[1]) {
    Import-Csv -Path "$userlist" | ForEach-Object {
        Get-UserByEmail -Email "$($_.emailAddress)"
    } | Select-Object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department,l | Export-Csv "$outfile" -NoTypeInformation
} elseif ($type -eq $types[2]) {
    Import-Csv -Path "$userlist" | ForEach-Object {
    Get-UserByEid -EmployeeId "$($_.employeeId)"
    } | Select-Object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l | Export-Csv "$outfile" -NoTypeInformation
} else {
    Write-Output "Search type not recognized. Enter either name, email or employeeid for the search type."
}