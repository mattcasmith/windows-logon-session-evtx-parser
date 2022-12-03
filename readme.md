# MCAS Windows Logon Session EVTX Parser v0.1
PowerShell script for parsing login sessions from the Windows Security event log<br />
<a href="https://mattcasmith.net">MattCASmith.net</a> | <a href="https://twitter.com/mattcasmith">@MattCASmith</a>

```diff
- This script is a learning/hobby project and some aspects may not follow best practices.
- While you're welcome to use it, you do so at your own risk. Make sure you take a backup
- of your files before trying it out, and don't go running it in production without
- proper checks.
```

### Introduction

The Windows Logon Session EVTX Parser is a script that reads either a live or an exported Windows Security event log and produces a list of login sessions, including the login and logout times.

Granted, Windows event logs - and particularly these events - are likely among the first logs you would onboard to a security information and event management (SIEM) tool in a corporate environment, but there may be situations where data isn't so accessible - for example, when investigating a host that has not been onboarded to the central repository, or a personal device involved in a forensics case.

The Windows Security event log generates events with the ID <a href="https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4624" target="_blank"><code>4624</code></a> whenever a user logs in. These events contain a multitude of useful information, from the timestamp and username to the login type (e.g. local or remote) and - where relevant - the remote IP address used. When the user logs out, some combination of the events <a href="https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4634" target="_blank"><code>4634</code></a> and <a href="https://www.ultimatewindowssecurity.com/securitylog/encyclopedia/event.aspx?eventID=4647" target="_blank"><code>4647</code></a> is generated (see the links for more information on what and when).

These events are linked together by a common field called <code>Logon ID</code>, which is a pseudo-unique value specific to a single login session. But there's a catch - Windows doesn't make it very easy to use this data because the value is buried in each event's <code>Message</code> field. The Event Viewer doesn't allow you to sort or filter based on it, and this gets crumpled into a single, hard-to-read cell in a CSV export.

<img src="https://mattcasmith.net/wp-content/uploads/2022/12/windows_logon_session_evtx_parser_0.png">

This is where the Windows Logon Session EVTX Parser comes in. Run the PowerShell script against a Windows Security event log and it will automatically find login and logout events, extract the relevant data from the <code>Message</code> field, correlate events to identify login sessions, and present the findings in a neat table.

#### Testing and limitations

Testing of the Windows Logon Session EVTX Parser is an ongoing process. The script is still a little rough around the edges (hopefully you'll give me a pass on that one, given the circumstances under which I wrote it) and currently does not include error handling, so you may have to do some manual investigation if anything goes wrong. However, I have tested all the options (live and exported event logs, different verbosity levels, CSV and terminal-only output) and everything seems to be in working order.

### Configuration

The Windows Logon Session EVTX Parser is relatively easy to configure by directly editing the variables within the script itself. There are three primary settings that can be adjusted to your needs.

|**Variable** |**Example** |**Purpose** |
|------------ |----------- |----------- |
|<code>$logFile</code> |C:\temp\export.evtx |Either set to the path of an exported Windows Security event log EVTX file, or leave blank to use the live log (script must be run with administrator privileges if accessing live logs) |
|<code>$verbosity</code> |1 |Must be set to one of the three verbosity settings (<a href="#verbosity">see below</a>) |
|<code>$outputFile</code> |C:\temp\logon_sessions.csv |Either set a path to write a CSV file of logon sessions to, or leave blank to print logon sessions to the terminal only |

Once the variables have been configured, the script can be run as a standard PowerShell script. If you wish to read the live event log, ensure that you are running the script from an administrator prompt.

```
.\windows-logon-session-evtx-parser.ps1
```

#### Verbosity

The <code>$verbosity</code> variable is perhaps the one that requires the most explanation. There are three possible levels of verbosity, and each has its own benefits and caveats, detailed below.

Setting <code>$verbosity</code> to <code>1</code> will exclude <code>SYSTEM</code> account logons and limit output to complete logon sessions (i.e. those with events for both the user logging in and logging out). This provides the most concise results, but will exclude any active sessions that do not yet have logout events, meaning it is best used in scenarios where its is known that the subject of the investigation is no longer active.

Setting <code>$verbosity</code> to <code>2</code> will still exclude <code>SYSTEM</code> account logons, but include a row in the output for each other login event, even if it does not have an associated logout event. This is likely the most useful verbosity level in most scenarios, as the results will include active sessions.

Setting <code>$verbosity</code> to <code>3</code> will include a row in the output for all logins, including those for the <code>SYSTEM</code> account and those with no associated logout event. This setting provides the most complete output, but includes a lot of noise from the <code>SYSTEM</code> account that you'll probably need to filter out yourself.

### Reading the output

Assuming you've populated the <code>$outputFile</code> variable, the Windows Logon Session EVTX Parser will drop a CSV containing output of your selected verbosity at your chosen path. In the example below, the script returned complete login sessions only (<code>$verbosity = 1</code>), and I have filtered out service account events.

<img src="https://mattcasmith.net/wp-content/uploads/2022/12/windows_logon_session_evtx_parser_1.png">

The timestamp and event ID columns are self-explanatory, but you might be wondering why I decided to include both <code>LoginUserName</code> and <code>LogoutUserName</code>. This is because when the user logs in using a Microsoft account, the login event shows the email address and the logout event shows the short/local username, so this can therefore be a useful way of correlating the two to determine which are related.

<code>LoginType</code> shows <a href="https://eventlogxp.com/blog/logon-type-what-does-it-mean/" target="_blank">the Windows logon type</a>, which helps to understand _how_ the user logged on. In the example, I have highlighted a Type 3 (Network) logon to a shared folder from a virtual machine in orange, and a Type 4 (Batch) logon in green (this is actually the scheduled task for my backup utility, <a href="https://mattcasmith.net/2021/01/01/backutil-windows-backup-utility">Backutil</a>).

I'd recommend opening the output CSV in Excel and playing around with filters - particularly if you've run the script at the higher verbosity levels - but I'm sure most people reading this are already familiar.

### Future development

As I mentioned earlier, the script is still rough in some areas, so when I have the time I would like to make a few improvements to tidy things up and improve functionality. These include:

* **General housekeeping** - The script was written in a single day while I was feeling rather groggy, so there are almost certainly omissions, inefficiencies, and so on that I'll find on review.

* **Error handling** - The script will currently run to completion while throwing PowerShell errors if something goes wrong. I'd like to add some proper error handling to deal with that more gracefully.

* **Additional functionality** - I would consider adding the option to include further events associated with Windows login sessions (e.g. failed logins) to the results at some point in future, and possibly the capability for the configuration variables to be provided via the command line.

Have you got more ideas for how the script could be improved? Or have you found bugs that I haven't? Please <a href="mailto:mattcasmith@protonmail.com">send me an email</a> to let me know so I can add them to the development backlog.

If you're interested in the project, check back regularly for new releases. I'll also announce any updates on <a target="_blank" href="https://twitter.com/mattcasmith">my Twitter account</a>, and may add some form of banner to <a href="https://mattcasmith.net">my site's homepage</a>.