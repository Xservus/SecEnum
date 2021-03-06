#Windows Security Configuration Enumeration
#Version 0.3
#Author: MrR3b00t (Dan Card)
#Copyright Xservus Limited
#Date: 21/01/2019
#staus: draft - use at your own risk
#use for good, not evil!


$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$admin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if($admin -eq 'True'){write-host "Running as admin"}else{write-host "Running in useland" -ForegroundColor Blue}

write-host $admin

$computer = Get-ComputerInfo

Write-Host "Windows Version Name: " $computer.WindowsProductName
Write-Host "Windows Build Version: " $computer.WindowsCurrentVersion
Write-Host "Computer Manufacturer: " $computer.CsManufacturer
write-host "Architecture: " $computer.OsArchitecture



#check if a TPM exists using the Get-TPM Modue
$TPM = Get-Tpm

if($TPM.TpmPresent -eq 'True')
{write-host "TPM Chip Present"}
else
{Write-host "TPM Chip Not Located using get-TPM Module attempting userland identification:" -ForegroundColor Red

$TPMUserland = Get-WmiObject -Class Win32_SystemDriver | Where-Object -FilterScript {$_.State -eq "Running" -and $_.DisplayName -eq "TPM"}

}
if($TPMUserland.State -eq "Running"){
write-host "TPM Chip located as running using WMI Win32_SystemDriver"
}
else
{
write-host "TPM Chip Not Detected"
}




write-host "Auditing Credential Guard"

$DevGuard = Get-CimInstance –ClassName Win32_DeviceGuard –Namespace root\Microsoft\Windows\DeviceGuard

if ($DevGuard.SecurityServicesConfigured -contains 1) {"Credential Guard configured"}else{write-host "Credential Guard NOT configured" -ForegroundColor Red}
if ($DevGuard.SecurityServicesRunning -contains 1) {"Credential Guard running"}else{write-host "Credential Guard NOT running" -ForegroundColor Red}



############ Defender ###################
#modified from https://gallery.technet.microsoft.com/scriptcenter/PowerShell-to-Check-if-811b83bc

Try 
{ 
 $defenderOptions = Get-MpComputerStatus -ErrorAction Stop
 
 if([string]::IsNullOrEmpty($defenderOptions)) 
 { 
  Write-host "Windows Defender was not found running on the Server:" $env:computername -foregroundcolor "Green" 
 } 
 else 
 { 
  Write-host "Windows Defender was found on the Server:" $env:computername -foregroundcolor "Green" 
  Write-host "Windows Defender Enabled:" $defenderOptions.AntivirusEnabled 
  Write-host "Windows Defender Service Enabled:" $defenderOptions.AMServiceEnabled 
  Write-host "Windows Defender Antispyware Enabled:" $defenderOptions.AntispywareEnabled 
  Write-host "Windows Defender OnAccessProtection Enabled:"$defenderOptions.OnAccessProtectionEnabled 
  Write-host "Windows Defender RealTimeProtection Enabled:"$defenderOptions.RealTimeProtectionEnabled
  write-host "Windows Defender Behaviour Monitor Enabled:" $defenderOptions.BehaviorMonitorEnabled
  write-host "Windows Defender Behaviour Monitor Enabled:" $defenderOptions.BehaviorMonitorEnabled


  #Get exclusions etc.

  $defprefs = Get-MpPreference

write-host "Windows Defender Net Protection:" $defprefs.EnableNetworkProtection
write-host "Windows Defender Extention Exclusions:" $defprefs.ExclusionExtension
write-host "Windows Defender Path Exclusions:" $defprefs.ExclusionPath
write-host "Windows Defender Process Exclusions:" $defprefs.ExclusionProcess
write-host "Windows Defender MAPS Reporting:" $defprefs.MAPSReporting

 } 
} 
Catch 
{ 
 Write-host "Windows Defender was not found running on the Server:" $env:computername -foregroundcolor "Red" 
}

#check if bitlocker is possible
Try
{
$bitlocker = Get-BitLockerVolume


}
Catch
{write-host "Bitlocker Not Supported/Enabled" -ForegroundColor "Red"}

if($bitlocker){}else{}

#Device Guard
# is configured in this policy
# Computer Configuration\Administrative Templates\System\Device Guard






#check windows defender passive mode
#read the registry

write-host "Checking for Windows Defender Passive Mode" -ForegroundColor Cyan
try{
Get-ChildItem 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'

Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'

#check AllowSampleCollection
#check Status

try{Get-ChildItem 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\Status'

if(
Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-Sense" ;ID=84} -ErrorAction Stop){write-host "Found Passivde Mode Enabled Event"}
else
{write-host "Did not locate Defender Passive Mode Event"  -ForegroundColor DarkYellow}

}
catch

{
write-host "Windows Defender Passive Mode not enabled" -ForegroundColor DarkYellow
}



}catch{write-host "Could not locate WD ATP Status"  -ForegroundColor DarkYellow}

################Service Enumeration #################


#get running services
#Get-Service |? Status -EQ Running
#get-service | ExecuteCommand

Get-WmiObject win32_service | select Name, DisplayName, State, PathName | FT -AutoSize -Wrap

#search for unquoted service paths
#needs to be combined with a permissions check or is kind of irrelevent if we can't abuse it

$Services = Get-Service |? Status -eq Running



write-host "There are: " $Services.Count " running on this OS"



#Locate AV Product
#this Namespace in WMI does not exist on server operating systems

write-host "Crude security product detection in progress...." -ForegroundColor Cyan

try{
$AntivirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Query "SELECT * FROM AntiVirusProduct" -ErrorAction Stop
}
catch
{
write-host "Unable to locate security products in root\SecurityCenter2 wmi namespace" -ForegroundColor Red
}

##############hunt for other security produts ##############################
#experimental and may contain false positives or completely miss products
############################################################################

write-host "Searching add/remove programs...." -ForegroundColor Cyan

####we should really write a dictionary and search it (maybe load it from a seperate text file)
try{
Get-WmiObject -Class Win32_Product|? Name -Contains "Trend"
Get-WmiObject -Class Win32_Product|? Name -Contains "Sophos"
Get-WmiObject -Class Win32_Product|? Name -Contains "Symantec"
Get-WmiObject -Class Win32_Product|? Name -Contains "EndGame"
Get-WmiObject -Class Win32_Product|? Name -Contains "Panda"
Get-WmiObject -Class Win32_Product|? Name -Contains "Avast"
Get-WmiObject -Class Win32_Product|? Name -Contains "Kaspesky"
Get-WmiObject -Class Win32_Product|? Name -Contains "ClamAV"
Get-WmiObject -Class Win32_Product|? Name -Contains "Emisoft"
Get-WmiObject -Class Win32_Product|? Name -Contains "Malwarebytes"
Get-WmiObject -Class Win32_Product|? Name -Contains "AVG"
Get-WmiObject -Class Win32_Product|? Name -Contains "F-Prot"
Get-WmiObject -Class Win32_Product|? Name -Contains "Webroot"
Get-WmiObject -Class Win32_Product|? Name -Contains "ZoneAlarm"
Get-WmiObject -Class Win32_Product|? Name -Contains "Security"
Get-WmiObject -Class Win32_Product|? Name -Contains "Firewall"
Get-WmiObject -Class Win32_Product|? Name -Contains "Encrypt"
}
catch
{write-host "unable to locate suspicious 3rd party defence technologies to investigate" -ForegroundColor Cyan}

#Look for really weak security configurations

#check we can read
try{test-path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"}catch{write-host "unable to read winlogon key" -ForegroundColor Red}


$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "AutoAdminLogon"
write-host "admin auto loggon enabled = " $key.AutoAdminLogon

$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "DefaultDomainName" -ErrorAction Continue
write-host $key.DefaultDomainName -ErrorAction Continue
$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "DefaultUserName" -ErrorAction Continue
write-host $key.DefaultUserName -ErrorAction Continue
$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "DefaultPassword" -ErrorAction Continue
write-host $key.DefaultPassword -ErrorAction Continue
$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "AltDefaultDomainName" -ErrorAction Continue
write-host $key.AltDefaultDomainName -ErrorAction Continue
$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "AltDefaultUserName" -ErrorAction Continue
write-host $key.AltDefaultUserName -ErrorAction Continue
$key = Get-itemproperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\" -name "AltDefaultPassword" -ErrorAction Continue
write-host $key.AltDefaultPassword -ErrorAction Continue
######Check if WSL is deployed #########

try{
Test-Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | %{Get-ItemProperty $_.PSPath} | out-string -width 4096
}
catch{
write-host "WSL not detected" -ForegroundColor Cyan

}



#################STEAL WIRELESSS KEYS#########################

netsh.exe wlan show profiles

netsh.exe wlan show profiles name='xservus-Wifi' key=clear

########### GET WINDOWS CREDENTIAL MANAGER KEYS###################


    [void][Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
    $vault = New-Object Windows.Security.Credentials.PasswordVault
    $vault.RetrieveAll() | % { $_.RetrievePassword();$_ }


#Get DNS Servers
Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName .

Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName . | Select-Object -Property [a-z]* -ExcludeProperty IPX*,WINS*
$dns = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName . | Select-Object -Property [a-z]* -ExcludeProperty IPX*,WINS*

foreach($server in $dns.DNSServerSearchOrder){
write-host $server

if($server -eq "1.1.1.1"){write-host "Protective DNS Located"}
if($server -eq "9.9.9.9"){write-host "Protective DNS Located"}

if($server -eq "208.67.222.222"){write-host "Protective DNS Located"}
if($server -eq " 208.67.220.220"){write-host "Protective DNS Located"}

if($server -eq "208.67.222.123"){write-host "Protective DNS Located"}
if($server -eq "208.67.222.123"){write-host "Protective DNS Located"}
}

#Get DISK INFO

Get-WmiObject -Class Win32_LogicalDisk | select -Property *

#this only works with admin rights
#Get DISK Bit Locker INFO
Get-WmiObject -Class Win32_EncryptableVolume -Namespace root\CIMV2\Security\MicrosoftVolumeEncryption
Get-BitLockerVolume
