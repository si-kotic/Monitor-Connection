<#

.SYNOPSIS

Monitors connection to a specific host.

Written by Simon Brown (2013).

.DESCRIPTION

Monitor-Connection will constantly PING a specified destination

and report on any responses which took longer than a specified

time both via e-mail and output to a CSV file.

.PARAMETER computer

Specifies the name of the computer to which you would like to

test the connection.

.PARAMETER responsethreshold

Specifies the response time which, if exceeded, will generate

an e-mail alert and log to a CSV file.

.PARAMETER failurethreshold

Specifies the number of failures to accept within a minute.

If this number is exceeded then the script will terminate and

an e-mail will be sent to the user explaining that there is a

definite problem with the connection.

.PARAMETER mailto

Specify the address to receive the e-mail alerts.  If no address

is specified then the alerts are sent to username@domainname

(ie administrator@aps-cambridge.local).

.PARAMETER mailfrom

Specifies the address from which alerts appear to have been sent.

If no address is specified then alerts are sent from

"IT@efstechnology.com".

.PARAMETER mailserver

Specifies the mail server used to send the alerts.  If no server is

specified then a default of "sbs001.aps-cambridge.local") is used.

.PARAMETER export

Specify the file to which failures are logged.  This must be the

full path including filename and extension.  If no path is specified

then a default of "C:\Temp\Monitor-Connection To $Computer.csv" is

used; where $Computer is the name of the computer being monitored.

#>
Function Monitor-Connection {
[CmdletBinding(SupportsShouldProcess=$true)]
Param (
[Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=1)][string]$Computer,
[int32]$ResponseThreshold = 500,
[int32]$FailureThreshold = 5,
[string]$mailTo = $env:USERNAME + "@" + $env:USERDNSDOMAIN, #"simonb@efstechnology.com",
[string]$mailFrom = "IT@EFSTechnology.com",
[string]$mailServer = "sbs002.aps-cambridge.local",
[string]$Export = "C:\Temp\Monitor-Connection To $Computer.csv"
)

Write-Verbose -Message "SET count, threshold, maxresponse AND pingdest VARIABLES"
$count = 0
$threshold = $FailureThreshold
$maxResponse = $ResponseThreshold
$pingDest = $Computer
$inc = 0 #Number of times the script has looped through (used for calculating average response time)
$cumulativeResponseTime = 0
$averageResponseTime = 0

Write-Verbose -Message "CREATE TABLE"
$table = New-Object system.Data.DataTable “Connection Status”

Write-Verbose -Message "CREATE COLUMNS"
$col1 = New-Object system.Data.DataColumn Date,([string])
$col2 = New-Object system.Data.DataColumn Source,([string])
$col3 = New-Object system.Data.DataColumn Destination,([string])
$col4 = New-Object system.Data.DataColumn PacketSize,([string])
$col5 = New-Object system.Data.DataColumn ReplyPacketSize,([string])
$col6 = New-Object system.Data.DataColumn ResponseTime,([string])
$col7 = New-Object system.Data.DataColumn TTL,([string])
$col8 = New-Object system.Data.DataColumn AverageResponseTime,([string])

Write-Verbose -Message "ADD COLUMNS TO TABLE"
$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)

While ($count -lt $threshold) {
	Write-Verbose -Message "PING $pingDest"
	$ping = Test-Connection $pingDest -Count 1
	$inc++
	$cumulativeResponseTime = $cumulativeResponseTime + $ping.ResponseTime
	IF (($ping.ResponseTime -gt $maxResponse) -or (!$ping))
	{
		$count ++
		IF ($ping)
		{
			Write-Verbose -Message "PING TOOK TOO LONG TO RESPOND"
			$mailSubject = ("$Computer took " + $ping.responsetime + "ms to respond")
		}
		ELSE
		{
			$cumulativeResponseTime = $cumulativeResponseTime + 4000
			Write-Verbose -Message "PING FAILURE!"
			$mailSubject = "$Computer failed to respond to a PING request"
		}
		Write-Verbose -Message "SEND MAIL MESSAGE"
		Send-MailMessage -To $mailTo -Subject $mailSubject -Body ("$Computer has failed to respond, or failed to respond within a reasonable time.  This has happened $count time(s) in the last 60 seconds.") -Priority High -SmtpServer $mailServer -From $mailFrom
		$lastFail = Get-Date
		Write-Verbose -Message "CREATE NEW ROW IN TABLE AND UPDATE FIELDS"
		$row = $table.NewRow()
		$row.Date = $lastFail.ToShortDateString() + " " + $lastFail.ToShortTimeString()
		$row.Source = $ping.PSComputerName
		$row.Destination = $ping.IPV4Address
		$row.PacketSize = $ping.BufferSize
		$row.ReplyPacketSize = $ping.ReplySize
		$row.ResponseTime = $ping.ResponseTime
		$row.TTL = $ping.ResponseTimeToLive
		$row.AverageResponseTime = $cumulativeResponseTime/$inc
		Write-Verbose -Message "COMMIT ROW TO TABLE"
		$table.rows.add($row)
		#$ping | Select-Object PSComputerName, IPV4Address, BufferSize, ProtocolAddress, ReplySize, ResponseTime, ResponseTimeToLive | Export-Csv -Path E:\Temp\pingscript.csv -Append
		Write-Verbose -Message "EXPORT TABLE TO $export"
		$table | Export-Csv -Path $Export -Append
		#Write-Output $ping
		Write-Output $table | Format-Table
	}
	ELSE
	{
		IF ($lastFail -lt (Get-Date).AddSeconds(-60))
		{
			Write-Verbose -Message "LAST FAILURE WAS MORE THAN 60 SECONDS AGO.  RESETTING COUNTER."
			$count = 0
		}
	}
	IF ($count -eq ($threshold-1))
	{
		Write-Verbose -Message "COUNTER THRESHOLD REACHED.  SENDING MAIL MESSAGE AND TERMINATING SCRIPT"
		Send-MailMessage -To $mailTo -Subject ("Connection Issue!") -Body ("The script has terminated because there is an issue with the connection to $Computer which needs to be investigated immediately!") -Priority High -SmtpServer $mailServer -From $mailFrom
	}
}
}


#	Quick Gauge of Avg Response Time
#Test-Connection 192.168.100.253 -Count 20 | foreach {$cnt++; $time = $time + $_.ResponseTime; Write-Output ("Average Response Time: " + $time/$cnt)}