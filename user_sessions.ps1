Write-Output ""
Write-Output "***************************************************"
Write-Output "WINDOWS LOGON SESSION EVTX PARSER"
Write-Output "by Matt C. A. Smith - MattCASmith.net, @mattcasmith"
Write-Output "***************************************************"
Write-Output ""

### VARIABLES ###
Write-Output "[+] Parsing variables..."
# Log file - leave blank for live event log (must be run as administrator)
$logFile = "F:\Desktop\test_security.evtx"
# Verbosity (1 - complete sessions only, 2 - all events, no SYSTEM account, 3 - all events)
$verbosity = 1
# CSV output file - leave blank for terminal-only results
$outputFile = "F:\Desktop\login_sessions.csv"

### Print variable info
if ($logFile -eq "")
{
    Write-Output "[+] Reading live Security log - must be run as administrator"
} else {
    Write-Output "[+] Reading static EVTX file from $logFile"
}
if ($verbosity -eq 1)
{
    Write-Output "[+] Verbosity: 1 (complete sessions only)"
} elseif ($verbosity -eq 2)
{
    Write-Output "[+] Verbosity: 2 (all events, no SYSTEM account)"
} elseif ($verbosity -eq 3)
{
    Write-Output "[+] Verbosity: 3 (all events)"
} else 
{
    Write-Output "[+] Invalid verbosity selected"
}
if ($outputFile -eq "")
{
    Write-Output "[+] No path provided - CSV will not be written"
} else
{
    Write-Output "[+] CSV will be written to $outputFile"
}

### Get events from Security log
$loginEvents = @()
$logoutEvents = @()
if ($logFile -eq "")
{
    Write-Output "[+] Retrieving events from Security log..."
    $tempLoginEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624}
    $tempLogoutEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4634,4647}
} else {
    Write-Output "[+] Retrieving events from $logFile..."
    $tempLoginEvents = Get-WinEvent -FilterHashtable @{Path=$logFile; ID=4624}
    $tempLogoutEvents = Get-WinEvent -FilterHashtable @{Path=$logFile; ID=4634,4647}
}

### Retrieve login event data (required fields: timestamp, username, logon type, logon ID)
Write-Host "[+] Processing login event fields..."
foreach ($event in $tempLoginEvents)
{
    $tempTable = @{}
    $eventXML = [xml]$event.ToXml()
    $loginEvents += @{
        LoginTime = $event.timecreated;
        LoginEventID = $event.id;
        LoginUserName = $eventXML.Event.EventData.Data[5].'#text';
        LoginType = $eventXML.Event.EventData.Data[8].'#text';
        LoginIP = $eventXML.Event.EventData.Data[18].'#text';
        LoginID = $eventXML.Event.EventData.Data[7].'#text'
    }
}
# Convert to a usable format and exclude events for local machine account
if ($verbosity -ne 3)
{
    $loginEvents = $loginEvents | % {New-Object PSObject -Property $_} | Where-Object {$_.LoginUserName -ne 'SYSTEM'}
} else
{
    $loginEvents = $loginEvents | % {New-Object PSObject -Property $_}
}

### Retrieve logout event data (required fields: timestamp, username, logon ID)
Write-Host "[+] Processing logout event fields..."
foreach ($event in $tempLogoutEvents)
{
    $tempTable = @{}
    $eventXML = [xml]$event.ToXml()
    $logoutEvents += @{
        LogoutTime = $event.timecreated;
        LogoutEventID = $event.id;
        LogoutUserName = $eventXML.Event.EventData.Data[1].'#text';
        LoginID = $eventXML.Event.EventData.Data[3].'#text'
    }
}
# Convert to a usable format and exclude events for local machine account
if ($verbosity -ne 3)
{
    $logoutEvents = $logoutEvents | % {New-Object PSObject -Property $_} | Where-Object {$_.UserName -ne 'SYSTEM'}
} else
{
    $logoutEvents = $logoutEvents | % {New-Object PSObject -Property $_}
}

### Match login and logout events based on the common LoginID field to find full session info
Write-Host "[+] Finding Logon ID matches..."
$combinedEvents = @()
foreach ($login in $loginEvents)
{
    foreach ($logout in $logoutEvents)
    {
        $matchFound = 0
        if ($login.LoginID -eq $logout.LoginID)
        {
            $matchFound = 1
            # Filter out duplicate matches where login and logout times are identical
            $tempLIT = $login.LoginTime | Out-String
            $tempLOT = $logout.LogoutTime | Out-String
            if ($tempLIT -ne $tempLOT)
            {
                $combinedEvents += @{
                    LoginTime = $login.LoginTime;
                    LogoutTime = $logout.LogoutTime;
                    LoginEventID = $login.LoginEventID;
                    LogoutEventID = $logout.LogOutEventID;
                    LoginUserName = $login.LoginUserName;
                    LogoutUserName = $logout.LogoutUserName;
                    LoginType = $login.LoginType;
                    LoginIP = $login.LoginIP;
                    LoginID = $login.LoginID
                }
            }
        }
        # Add an entry for logins without logouts (i.e. active sessions)
        if ($matchFound -eq 0)
        {
            if ($verbosity -ne 1)
            {
                $combinedEvents += @{
                    LoginTime = $login.LoginTime;
                    LogoutTime = "";
                    LoginEventID = $login.LoginEventID;
                    LogoutEventID = "";
                    LoginUserName = $login.LoginUserName;
                    LogoutUserName = "";
                    LoginType = $login.LoginType;
                    LoginIP = $login.LoginIP;
                    # Exclude LoginID to avoid duplicate blanks in results
                    # LoginID = $login.LoginID
                }
            }
        }
        
     }
}
# Convert to a usable format, print to screen, and create CSV if path set
Write-Output "[+] Producing final table..."
Write-Output ""
$combinedEvents = $combinedEvents | % {New-Object PSObject -Property $_} | Sort-Object -Property LoginTime, LogoutTime, LoginEventID, LogoutEventID, LoginUserName, LogoutUserName, LoginType, LoginIP, LoginID -Unique
$combinedEvents | Select LoginTime, LogoutTime, LoginEventID, LogoutEventID, LoginUserName, LogoutUserName, LoginType, LoginIP, LoginID | Format-Table
if ($outputFile -ne "")
{
    Write-Output "[+] Writing CSV to $outputFile"
    $combinedEvents | Select LoginTime, LogoutTime, LoginEventID, LogoutEventID, LoginUserName, LogoutUserName, LoginType, LoginIP, LoginID | Export-Csv $outputFile -NoTypeInformation
}
Write-Output "[+] Finished - SUCCESS"
Write-Output ""