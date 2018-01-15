
Param(
  [string]$domainVersion,
  [string]$domainHost,
  [string]$domainName,
  [string]$domainUser,
  [string]$domainPassword,
  [int]$nodeCount,
  [string]$nodeName,
  [int]$nodePort,
  [string]$pcrsName,
  [string]$pcisName,

  [string]$dbNewOrExisting,
  [string]$dbType,
  [string]$dbName,
  [string]$dbTablespace,
  [string]$dbUser,
  [string]$dbPassword,
  [string]$dbHost,
  [int]$dbPort,
  [string]$pcrsDBType,
  [string]$pcrsUseDSN,
  [string]$pcrsDSN,
  [string]$pcrsDBUser,
  [string]$pcrsDBPassword,
  [string]$pcrsDBTablespace,

  [string]$sitekeyKeyword,

  [string]$joinDomain = 0,
  [string]$masterNodeHost,
  [string]$osUserName,

  [string]$storageName,
  [string]$storageKey,
  [string]$infaLicense
)

function executeCommand {
    Param([String]$command, [String]$logMesage = "No message", [bool]$exitOnFailure = $false, [int]$retry = 0)
    
    $counter = 0
    do {
        $error.Clear()
        Invoke-Expression $command -OutVariable outputMessage -ErrorVariable errorMessage
        $code = $error.Count

        $message = $(get-date -f MM-dd-yyyy_HH_mm_ss) + " " + $logMesage + ": " + $outputMessage + $errorMessage + ", Attempt: " + ++$counter
        ac $logHome $message
        --$retry
    } while($code -ne 0 -And $retry -gt 0)

    if($code -ne 0 -And $exitOnFailure -eq $true) {
        exit $code
    }
}

echo $domainHost $domainName $domainUser $domainPassword $nodeCount $nodeName $nodePort $pcrsName $pcisName $dbNewOrExisting $dbType $dbName $dbUser $dbPassword $dbHost $dbPort $sitekeyKeyword $joinDomain $masterNodeHost $osUserName $infaEdition $storageName $storageKey $infaLicense

#Adding Windows firewall inbound rule
echo "Adding firewall rules for Informatica domain service ports"
netsh  advfirewall firewall add rule name="Informatica_PowerCenter" dir=in action=allow profile=any localport=6005-6113 protocol=TCP

$shareName = "infaaeshare"

# Informatica version needs to be handled here
$infaHome = $env:SystemDrive + "\Informatica\10.1.1"
$installerHome = $env:SystemDrive + "\Informatica\Archive\informatica_1011HF1_server_winem-64t"
$utilityHome = $env:SystemDrive + "\Informatica\Archive\utilities"
$logHome = $env:SystemDrive + "\Informatica\Archive\service_creation.log"

#Setting Java in path
$env:JRE_HOME= $installerHome + "\source\java\jre"
$env:Path=$env:JRE_HOME+"\bin;" + $env:Path

# DB Configurations if required
$dbAddress = $dbHost + ":" + $dbPort

$userInstallDir = $infaHome
$defaultKeyLocation = $infaHome + "\isp\config\keys"
$propertyFile = $installerHome + "\SilentInput.properties"


# Check if license is provided and if it master node installation
$infaLicenseFile = ""
$CLOUD_SUPPORT_ENABLE = "1"
if($infaLicense -ne "#_no_license_#" -and $joinDomain -eq 0) {
	$infaLicenseFile = $env:SystemDrive + "\Informatica\license.key"
	echo "Getting Informatica license"
	wget $infaLicense -OutFile $infaLicenseFile

	if (Test-Path $infaLicenseFile) {
		$CLOUD_SUPPORT_ENABLE = "0"
	} else {
		echo "Error downloading license file from URL" + $infaLicense
	}
}

$createDomain = 1
if($joinDomain -eq 1) {
    $createDomain = 0
    # This is buffer time for master node to start
    Start-Sleep -s 300
} else {
	echo "Creating shared directory on Azure storage"
    cd $utilityHome
    java -jar iadutility.jar createAzureFileShare -storageaccesskey $storageKey -storagename "$storageName"
}

$env:USERNAME = $osUserName
$env:USERDOMAIN = $env:COMPUTERNAME

#Mounting azure shared file drive
echo "Mounting the shared directory"
$cmd = "net use I: \\$storageName.file.core.windows.net\$shareName /u:$storageName $storageKey" 
$cmd | Set-Content "$env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\MountShareDrive.cmd"

runas /user:$osUserName net use I: \\$storageName.file.core.windows.net\$shareName /u:$storageName $storageKey

echo "Editing Informatica silent installation file"
(gc $propertyFile | %{$_ -replace '^LICENSE_KEY_LOC=.*$',"LICENSE_KEY_LOC=$infaLicenseFile"  `
`
-replace '^CREATE_DOMAIN=.*$',"CREATE_DOMAIN=$createDomain"  `
`
-replace '^JOIN_DOMAIN=.*$',"JOIN_DOMAIN=$joinDomain"  `
`
-replace '^CLOUD_SUPPORT_ENABLE=.*$',"CLOUD_SUPPORT_ENABLE=$CLOUD_SUPPORT_ENABLE"  `
`
-replace '^ENABLE_USAGE_COLLECTION=.*$',"ENABLE_USAGE_COLLECTION=1"  `
`
-replace '^USER_INSTALL_DIR=.*$',"USER_INSTALL_DIR=$userInstallDir"  `
`
-replace '^KEY_DEST_LOCATION=.*$',"KEY_DEST_LOCATION=$defaultKeyLocation"  `
`
-replace '^PASS_PHRASE_PASSWD=.*$',"PASS_PHRASE_PASSWD=$sitekeyKeyword"  `
`
-replace '^SERVES_AS_GATEWAY=.*$',"SERVES_AS_GATEWAY=1" `
`
-replace '^DB_TYPE=.*$',"DB_TYPE=$dbTYPE" `
`
-replace '^DB_UNAME=.*$',"DB_UNAME=$dbUser" `
`
-replace '^DB_SERVICENAME=.*$',"DB_SERVICENAME=$dbName" `
`
-replace '^DB_ADDRESS=.*$',"DB_ADDRESS=$dbAddress" `
`
-replace '^DOMAIN_NAME=.*$',"DOMAIN_NAME=$domainName" `
`
-replace '^NODE_NAME=.*$',"NODE_NAME=$nodeName" `
`
-replace '^DOMAIN_PORT=.*$',"DOMAIN_PORT=$nodePort" `
`
-replace '^JOIN_NODE_NAME=.*$',"JOIN_NODE_NAME=$nodeName" `
`
-replace '^JOIN_HOST_NAME=.*$',"JOIN_HOST_NAME=$env:COMPUTERNAME" `
`
-replace '^JOIN_DOMAIN_PORT=.*$',"JOIN_DOMAIN_PORT=$nodePort" `
`
-replace '^DOMAIN_USER=.*$',"DOMAIN_USER=$domainUser" `
`
-replace '^DOMAIN_HOST_NAME=.*$',"DOMAIN_HOST_NAME=$domainHost" `
`
-replace '^DOMAIN_PSSWD=.*$',"DOMAIN_PSSWD=$domainPassword" `
`
-replace '^DOMAIN_CNFRM_PSSWD=.*$',"DOMAIN_CNFRM_PSSWD=$domainPassword" `
`
-replace '^DB_PASSWD=.*$',"DB_PASSWD=$dbPassword" 

}) | sc $propertyFile

if($dbType -eq "DB2" -and $dbTablespace -ne "#_no_tablespace_#") {
	(gc $propertyFile | %{$_ -replace '^DB2_TABLESPACE=.*$',"DB2_TABLESPACE=$dbTablespace"}) | sc $propertyFile
}

# To speed-up installation
Rename-Item $installerHome/source $installerHome/source_temp
mkdir $installerHome/source

echo "Installing Informatica domain"
cd $installerHome
$installCmd = $installerHome + "\silentInstall.bat"
Start-Process $installCmd -Verb runAs -workingdirectory $installerHome -wait | Out-Null

# Revert speed-up changes
rmdir $installerHome/source
Rename-Item $installerHome/source_temp $installerHome/source

# Remove license file from VM
if($infaLicenseFile -ne "") {
	rm $infaLicenseFile
}

# Change to installation directory
cd $infaHome

# Validate of installation
($out = isp\bin\infacmd ping -dn $domainName -nn $nodeName) | Out-Null
if($LASTEXITCODE -ne 0) {
	echo "Informatica domain setup failed"
	exit 255
}

echo "Informatica domain setup Complete"

# Get license name from domain
$licenseNameOption = ""
if($infaLicense -ne "#_no_license_#") {
	($out = isp\bin\infacmd listLicenses -dn $domainName -un $domainUser -pd $domainPassword) | Out-Null
	($licenseName = $out -split ' ' | select -First 1)
	$licenseNameOption = "-ln " + $licenseName
}

# Creating PC services
if($joinDomain -eq 0 ) {
    if(-not [string]::IsNullOrEmpty($pcrsDBUser) -and -not [string]::IsNullOrEmpty($pcrsDBPassword)) {
		echo "Creating PowerCenter services"

	    switch -Wildcard ($dbType) {
            "MSSQLServer" {
                $pcrsDBType = "MSSQLServer"
			    $pcrsConnectString = $dbHost + "@" + $dbName
			    $pcrsTablespace = ""    
            }
            "Oracle" {
                $pcrsDBType = "Oracle"
			    $pcrsConnectString = $dbName
			    $pcrsTablespace = ""    
            }
            "DB2" {
                $pcrsDBType = "DB2"
			    $pcrsConnectString = $dbName
			    $pcrsTablespaceOption = "TablespaceName=" + $dbTablespace    
            }
            default {
                echo "Unsupported database"
			    exit 255
            }
        }

        $repoCmd = "$infaHome\isp\bin\infacmd createRepositoryService -dn $domainName -nn $nodeName -sn $pcrsName -so DBUser=$pcrsDBUser DatabaseType=$pcrsDBType DBPassword=""$pcrsDBPassword"" ConnectString=""$pcrsConnectString"" CodePage=""MS Windows Latin 1 (ANSI), superset of Latin1"" OperatingMode=NORMAL $pcrsTablespaceOption -un $domainUser -pd $domainPassword -sd true $licenseNameOption"
        executeCommand $repoCmd "Create Repository service" $true

        #Debug 
        echo "Node count $nodeCount"

		if ($nodeCount -eq 1) {
            
			$intCmd = "$infaHome\isp\bin\infacmd createintegrationservice -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn $pcisName -rs  $pcrsName -ru $domainUser -rp $domainPassword $licenseNameOption -po codepage_id=2252 -sd -ev INFA_CODEPAGENAME=MS1252"
			executeCommand $intCmd "Create Integration service" $true 
		} else {

			$gridCmd = "$infaHome\isp\bin\infacmd creategrid -dn $domainName -un $domainUser -pd $domainPassword -gn grid -nl $nodeName"
			executeCommand $gridCmd "Create Grid" $true 

			$intCmd = "$infaHome\isp\bin\infacmd createintegrationservice -dn $domainName -gn grid -un $domainUser -pd $domainPassword -sn $pcisName -rs  $pcrsName -ru $domainUser -rp $domainPassword $licenseNameOption -po codepage_id=2252 -sd -ev INFA_CODEPAGENAME=MS1252"
			executeCommand $intCmd "Create Integration service on Grid" $true 

			$updSrvCmd = "$infaHome\isp\bin\infacmd updateServiceProcess -dn $domainName -un $domainUser -pd $domainPassword -sn $pcisName -nn $nodeName -po CodePage_Id=2252"
			executeCommand $updSrvCmd "Update Integration service process" $true  
		}
	}
} else { 
    $updGrdCmd = "$infaHome\isp\bin\infacmd updategrid -dn $domainName -un $domainUser -pd $domainPassword -gn grid -nl $nodeName -ul"
    executeCommand $updSrvCmd "Updating the grid with node" $true 3

	$updSrvCmd = "$infaHome\isp\bin\infacmd updateServiceProcess -dn $domainName -un $domainUser -pd $domainPassword -sn $pcisName -nn $nodeName -po CodePage_Id=2252 -ev INFA_CODEPAGENAME=MS1252"
	executeCommand $updSrvCmd "Update Integration service process" $true 3
}