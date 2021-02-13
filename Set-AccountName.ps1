Import-Module ActiveDirectory

clear
# User Email Address Args
$email = $args[0]

$yes = "y"

$newline = "`r`n"

# If no argument passed, get input from command line
if ( $email -eq $null ) {
    $email = Read-Host -Prompt "[~] Enter the user's current email address"
    $user = Get-ADUser -Filter "emailAddress -like '*$($email.TrimEnd())*'" -Properties Name,DisplayName,givenName,surname,emailAddress,employeeId
}
else {
    $user = Get-ADUser -Filter "emailAddress -like '*$($email.TrimEnd())*'" -Properties Name,DisplayName,givenName,surname,emailAddress,employeeId
}


# Print User Details
$newline

Write-Host -ForegroundColor Green "[=] User Details Retrieved:"

$user

# Confirmation
$confirmation1 = Read-Host -Prompt "[?] Would you like to perform a name change on the user above? Enter [y] to continue or any other key to exit"
if ( $confirmation1 -ne $yes ) {
    exit
}

# Empty and Store User's eid in variable

Write-Host -ForegroundColor Green "[+] Storing EmployeeID..."

$eid = $null
$user | Select-Object -ExpandProperty employeeId | Write-Output -OutVariable +script:eid

# Change user's name, email address, samaccountname and userprincipalname
    $Script:newgivenname = (Read-Host -Prompt "[~] Enter the user's First Name (case-sensitive)").Trim()

    $Script:newsurname = (Read-Host -Prompt "[~] Enter the user's Last Name (case-sensitive)").Trim()

    $Script:newpre2k = (Read-Host -Prompt "[~] Enter the user's new Pre2K (case-sensitive)").Trim()

    $newdisplayname = $newgivenname + " " + $newsurname

    $Script:useremailaddress = (Read-Host -Prompt "[~] Enter the user's new email address").ToLower().Trim()

    $Script:userprincipalname = $($useremailaddress.TrimEnd("carvana.com")) + "ad.carvana.com"

    Write-Host -ForegroundColor Green "[=] New User Information: "
    "[=] Name: " + $newdisplayname
    "[=] Email Address: " + $useremailaddress
    "[=] User Principal Name: " + $userprincipalname
    "[=] Pre2K: " + $newpre2k

    Write-Host -ForegroundColor White -BackgroundColor Red '[!] WARNING: You are about to make changes in Active Directory!!!'
    $confirmation2 = Read-Host -Prompt "[!] Carefully check the information above and enter [y] to continue or any other key to abort"
    if ( $confirmation2 -eq $yes ) {
        Write-Host -ForegroundColor Green '[+] Changing Name...'
        Get-AdUser -Filter "employeeId -eq '$eid'" | Rename-ADObject -NewName "$newdisplayname"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[+] Changing Display Name...'
        Get-Aduser -Filter "employeeId -eq '$eid'" | Set-Aduser -DisplayName "$newdisplayname"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[+] Changing First Name...'
        Get-Aduser -Filter "employeeId -eq '$eid'" | Set-Aduser -givenName "$newgivenname"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[+] Changing Last Name...'
        Get-Aduser -Filter "employeeId -eq '$eid'" | Set-Aduser -Surname "$newsurname"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[+] Changing User Principal Name...'
        Get-Aduser -Filter "employeeId -eq '$eid'" | Set-Aduser -UserPrincipalName "$userprincipalname"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[+] Changing Email Address...'
        Get-Aduser -Filter "employeeId -eq '$eid'" | Set-Aduser -EmailAddress "$useremailaddress"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[+] Changing Pre2K...'
        Get-Aduser -Filter "employeeId -eq '$eid'" | Set-Aduser -SamAccountName "$newpre2k"
        Start-Sleep -Seconds 3

        Write-Host -ForegroundColor Green '[$] Waiting for Active Directory data replication...'
        Start-Sleep -Seconds 8
        Write-Host -ForegroundColor Green '[$] Name Change Complete!! Current Name Information:'
        Get-ADUser -Filter "employeeId -eq '$eid'" -Properties * | Select-Object Name,DisplayName,givenName,surname,SamAccountName,emailAddress,UserPrincipalName
    } else {
      Write-Host -ForegroundColor Red '[$] Name change process aborted.'  
    }
Write-Host -ForegroundColor Green '[$] Name change process complete, thanks for playing!'
exit
