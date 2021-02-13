Import-Module ActiveDirectory

clear

# Search AD using employeeid
function Get-UserByEid {
    [CmdletBinding()]
    param(
        $EmployeeId,
        $Department
    )
    Get-ADUser -Filter "employeeId -eq '$EmployeeId'" -Properties * | Where {$_.Department -like "$Department"}
}

# Search AD using user's name
function Get-UserByName {
    [CmdletBinding()]
    param(
        $Name,
        $Department
    )
    Get-ADUser -Filter "Name -like '$Name'" -Properties * | Where {$_.Department -like "$Department"}
}

# search AD using user's emailAddress
function Get-UserByEmail {
    [CmdletBinding()]
    param(
        $Email,
        $Department
    )
    Get-ADUser -Filter "emailAddress -like '$Email'" -Properties * | Where {$_.Department -like "$Department"}
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
                $Str -replace $regex, "" -replace "'"
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
    Write-Host -ForegroundColor Green "The input .csv must ONLY contain the following case-sensitive headers: givenName,surname,Department"
    $type = $types[0]
} elseif ($type -like $types[1]) {
    Write-Host -ForegroundColor Green "The input .csv must ONLY contain the following case-sensitive headers: emailAddress,Department"
    $type = $types[1]
} elseif ($type -like $types[2]) {
    Write-Host -ForegroundColor Green "The input .csv must ONLY contain the following case-sensitive headers: employeeId,Department"
    $type = $types[2]
} else {
    Write-Host -ForegroundColor Red "Search type not recognized`r`nValid search types: name, email, employeeid"
    return
}

# Receive input and output files from stdin
if ($list -eq $null) {
    $list = Read-Host 'Enter the path to the input .csv file (e.g. C:\userlist.csv )'
}

if ($export -eq $null) {
    Write-Host -ForegroundColor Green "The output '.csv' file will include the following information: name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title"
    $export = Read-Host 'Enter the path to the desired output .csv file'
}

# Trim double quotes from filepath variables, fixes parsing errors
$userlist = $list.Trim('"')
$outfile = $export.Trim('"')

# Remove the output file if it exists
if (Test-Path -Path "$outfile") {
    Remove-Item -Path "$outfile"
}

# Search AD for each row of the input file based on type and output results to outfile or write error if previous type matching failed
if ($type -eq $types[0]) {
    Import-Csv -Path "$userlist" | ForEach-Object {
    $firstname = Remove-StringSpecialCharacter -String "$($_.givenName)" -SpecialCharacterToKeep "-"," "
    $lastname = Remove-StringSpecialCharacter -String "$($_.surname)"  -SpecialCharacterToKeep "-"," "
    $department = Remove-StringSpecialCharacter -String "$($_.Department)" -SpecialCharacterToKeep " "
    $result = Get-UserByName -Name "*$lastname*" -Department "*$department*" | Where {$_.givenName -like "*$firstname*"}
    if ($result -eq $null) {
        Write-Host  -ForegroundColor Yellow "`r`nName lookup for $firstname $lastname`'s AD account returned no results. Attempting to search by Email address..."
        $result = Get-UserByEmail -Email "*$firstname*$lastname*" -Department "*$department*"
        if ($result -eq $null) {
            Write-Host  -ForegroundColor Red "Lookup for $firstname $lastname returned no results. Verify the user's name or try searching AD manually."
            $nullresult = "Lookup Timestamp: $(Get-Date -UFormat "%m/%d/%Y %T"), no results found"
            $props = @{
                givenName = "$firstname"
                surname = "$lastname"
                name = "$firstname $lastname"
                emailAddress = "$nullresult"
                SamAccountName = "$nullresult"
                employeeId = "$nullresult"
                manageremail = "$nullresult"
                Title = "$nullresult"
                Department = "$nullresult"
                l = "$nullresult"
                Enabled = "$nullresult"
            }
            $result = New-Object PSObject -Property $props
        } 
    }
    $result } |
    Select-Object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l, Enabled | Export-Csv "$outfile" -NoTypeInformation
} elseif ($type -eq $types[1]) {
    Import-Csv -Path "$userlist" | ForEach-Object {
        Get-UserByEmail -Email "$($_.emailAddress)" -Department "*$($_.Department)*"
    } | Select-Object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l, Enabled | Export-Csv "$outfile" -NoTypeInformation
} elseif ($type -eq $types[2]) {
    Import-Csv -Path "$userlist" | ForEach-Object {
    Get-UserByEid -EmployeeId "$($_.employeeId)" -Department "*$($_.Department)*"
    } | Select-Object name, givenName, surname, emailAddress, SamAccountName, employeeId, manageremail, Title, Department, l, Enabled  | Export-Csv "$outfile" -NoTypeInformation
} else { 
    Write-Output -ForegroundColor Red "Search type not recognized. Enter either name, email or employeeid for the search type."
}