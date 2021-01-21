Import-Module ActiveDirectory

clear
$yes = "y" 
$newline = Write-Output "`r`n"

function Get-UserByEmail {
    while ( -Not $uservalidated ) {
        $email = Read-Host -Prompt "Enter the user's email address"
        $userdata = Get-ADUser -Filter "emailAddress -eq '$($email.Trim(' '))'" -Properties *
        if ( $userdata -eq $null ) {
            $tryvalidate1 = Read-Host -Prompt "User not found, would you like to try again? Enter [y] to continue or any other key to exit"
            if ( $yes -imatch $tryvalidate1 ) {
                continue
            }
            else {
                exit
            }
        }
        else {
            $uservalidated = $true
        }
    }
    return $userdata
}

function Get-Group {
     while ( -Not $groupvalidated ) {
        $groupname = Read-Host -Prompt "Enter the group name"
        $groupdata = Get-ADGroup -Filter "name -eq '$($groupname.Trim(' '))'" -Properties PrimaryGroupToken
        if ( $groupdata -eq $null ) {
            $tryvalidate1 = Read-Host -Prompt "Group not found, would you like to try again? Enter [y] to continue or any other key to exit"
            if ( $yes -imatch $tryvalidate1 ) {
                continue
            }
            else {
                exit
            }
        }
        else {
            $groupvalidated = $true
        }
    }
    return $groupdata
}

# Get User's Info and Current Groups
Write-Output "Stage 1: Set Target User"
$user = Get-UserByEmail
Write-Output "User Information:"
$user | Select-Object name,emailAddress,samAccountname,Enabled,DistinguishedName
$newline
$currentgroups = $user | Get-ADPrincipalGroupMembership | Select-Object -ExpandProperty name
Write-Output "Current group memberships: "
$currentgroups + $newline

Write-Output "Make sure a list of the user's Okta apps, GSuite DL's and the information above is saved in the ticket before continuing`r`n"

# Get Primary Group
Write-Output "Stage 2: Choose New Primary Group"
$primarygroup = Get-Group

# Check for confirmation to continue, else exit
Write-Output "`r`nNew Primary Group"
$primarygroup

$confirmation = Read-Host -Prompt "Do you want to proceed with changing the user's Primary Group? Enter [y] to continue or any other key to exit"
if ( $yes -ne $confirmation ) {
    exit
}

# Add user to primarygroup

Write-Output "Stage 3: Modify User's Primary Group.`r`nAdding the user to the group..."
try {
    $user | Add-ADPrincipalGroupMembership -MemberOf "$primarygroup"
}
catch {
    "User is already a member of the Specfied Group or an unknown error has occured."
}

Start-Sleep -Seconds 5

# Get group's primary group token
Write-Output "Getting group's token..."
$grouptoken = $primarygroup | Select-Object -ExpandProperty PrimaryGroupToken

# Replace user's existing primarygroupID
Write-Output "Setting the user's new Primary Group..."
$user | Set-ADUser -Replace @{primarygroupID=$grouptoken}
Start-Sleep -Seconds 5

# Verify the change was made successfully
Write-Host "Stage 4: Primary Group Validation"
while ( -Not $primarygrouptokenupdate ) {
        Write-Host "Confirming the change was made successfully, please wait..."
        Start-Sleep -Seconds 5
        # Pass $user variable to Get-ADUser and pull updated primarygroup token
        $userprimarygroupid = $user | Get-ADUser -Properties * | Select-Object -ExpandProperty primarygroupID
        if ( $grouptoken -ne $userprimarygroupid ) {
            $manualvalidate = Read-Host -Prompt "New Primary Group validation failed.`n Check the user's Primary Group manually and press enter when you are ready to continue`n"
        }
        else {
            $primarygrouptokenupdate = $true
        }
}

# Optionally, remove user from current groups
Write-Host "Stage 5a: Remove Current Groups"
$confirm2 = Read-Host -Prompt 'Would you like to remove the user from his current groups? Enter [y] to continue or any other key to continue'
 if ( $confirm2 -eq $yes ) {
        $user | Remove-ADPrincipalGroupMembership -MemberOf $currentgroups -ErrorAction SilentlyContinue
}

# Optionally, add user to a series of new groups
Write-Host "Stage 5b: Add New Groups"
$addgroupdone = $false
while ( -not $addgroupdone ) {
    $confirm3 = Read-Host -Prompt 'Would you like to add the user to any more groups? Enter [y] to continue or any other key to finish'
    if ( $yes -eq $confirm3 ) {
        $newgroup = Read-Host -Prompt 'Enter the name of the group you would like to add this user to'
        try {
            $user | Add-ADPrincipalGroupMembership -MemberOf "$($newgroup.Trim(' '))"
        }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                "The group could not be found. Please check the group display name."
        } 
        catch {
            "The user is already a member of the group or an error has occured that could not be resolved."
        }
    }
    else {
        $addgroupdone = $true
    }
}
$newline
Start-Sleep -Seconds 10
Write-Output "User Name:`r`n---"
$user | Select-Object -ExpandProperty name
$newline
Write-Output "Current Group Memberships:`r`n---"
$user | Get-ADPrincipalGroupMembership | Select-Object -ExpandProperty name
$newline
Write-Host "Primary Group Change Complete"
exit
