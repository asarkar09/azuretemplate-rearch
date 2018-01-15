#!/bin/sh

#Script arguments
domainVersion=${1}
domainHost=${2}
domainName=${3}
domainUser=${4}
domainPassword=${5}
nodeCount=${6}
nodeName=${7}
nodePort=${8}
pcrsName=${9}
pcisName=${10}

dbNewOrExisting=${11}
dbType=${12}
dbName=${13}
dbTablespace=${14}
dbUser=${15}
dbPassword=${16}
pcrsDBUser=${17}
pcrsDBPassword=${18}
dbHost=${19}
dbPort=${20}

sitekeyKeyword=${21}

joinDomain=${22}
osUserName=${23}

storageName=${24}
storageKey=${25}

domainLicenseURL=${26}

echo Starting Informatica setup...
echo Number of parameters $#
echo $domainVersion $domainHost $domainName $domainUser $domainPassword $nodeCount $nodeName $nodePort $pcrsName $pcisName $dbNewOrExisting $dbType $dbName $dbUser $dbPassword pcrsDBUser, pcrsDBPassword $dbHost $dbPort $sitekeyKeyword $joinDomain $osUserName $storageName $storageKey $domainLicenseURL

yum -y install cifs-utils

#Usage
if [ $# -ne 26 ]
then
	echo lininfainstaller.sh domainHost domainName domainUser domainPassword nodeName nodePort dbType dbName dbUser dbPassword dbHost dbPort sitekeyKeyword joinDomain  osUserName storageName storageKey domainLicenseURL
	exit -1
fi

dbaddress=$dbHost:$dbPort
hostname=`hostname`

informaticaopt=/opt/Informatica
infainstallerloc=$informaticaopt/Archive/server
utilityhome=$informaticaopt/Archive/utilities
logfile=$informaticaopt/Archive/logs/service_creation.log

mkdir -p $informaticaopt/Archive/logs

infainstallionlocown=/home/Informatica
#mkdir -p $infainstallionlocown/10.1.1

echo Creating symbolic link to Informatica installation
ln -s $infainstallionlocown /home/$osUserName

infainstallionloc=\\/home\\/Informatica\\/10.1.1
defaultkeylocation=$infainstallionloc\\/isp\\/config\\/keys
licensekeylocation=\\/opt\\/Informatica\\/license.key

# Firewall configurations
echo Adding firewall rules for Informatica domain service ports
iptables -A IN_public_allow -p tcp -m tcp --dport 6005:6008 -m conntrack --ctstate NEW -j ACCEPT
iptables -A IN_public_allow -p tcp -m tcp --dport 6014:6114 -m conntrack --ctstate NEW -j ACCEPT

JRE_HOME="$infainstallerloc/source/java/jre"
export JRE_HOME		
PATH="$JRE_HOME/bin":"$PATH"
export PATH

chmod -R 777 $JRE_HOME

cloudsupportenable=1
if [ "$domainLicenseURL" != "#_no_license_#" -a $joinDomain -eq 0 ]
then
	echo Getting Informatica license
	cd $utilityhome
	java -jar iadutility.jar downloadHttpUrlFile -url "$(echo $domainLicenseURL | sed -e s/\ /%20/g)" -localpath "$informaticaopt/license.key"

	if [ -f $informaticaopt/license.key ]
	then
		cloudsupportenable=0
	else
		echo Error downloading license file from URL $domainLicenseURL
	fi
fi


createDomain=1
if [ $joinDomain -eq 1 ]
then
    createDomain=0
	# This is buffer time for master node to start
	sleep 300
else
	echo Creating shared directory on Azure storage
	cd $utilityhome
    java -jar iadutility.jar createAzureFileShare -storageaccesskey $storageKey -storagename "$storageName"
fi

echo Mounting the shared directory
mountdir=/mnt/infaaeshare
mkdir $mountdir
mount -t cifs //$storageName.file.core.windows.net/infaaeshare $mountdir -o vers=3.0,username=$storageName,password=$storageKey,dir_mode=0777,file_mode=0777
echo //$storageName.file.core.windows.net/infaaeshare $mountdir cifs vers=3.0,username=$storageName,password=$storageKey,dir_mode=0777,file_mode=0777 >> /etc/fstab

echo Editing Informatica silent installation file
sed -i s/^LICENSE_KEY_LOC=.*/LICENSE_KEY_LOC=$licensekeylocation/ $infainstallerloc/SilentInput.properties

sed -i s/^USER_INSTALL_DIR=.*/USER_INSTALL_DIR=$infainstallionloc/ $infainstallerloc/SilentInput.properties

sed -i s/^CREATE_DOMAIN=.*/CREATE_DOMAIN=$createDomain/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_DOMAIN=.*/JOIN_DOMAIN=$joinDomain/ $infainstallerloc/SilentInput.properties

sed -i s/^CLOUD_SUPPORT_ENABLE=.*/CLOUD_SUPPORT_ENABLE=$cloudsupportenable/ $infainstallerloc/SilentInput.properties

sed -i s/^ENABLE_USAGE_COLLECTION=.*/ENABLE_USAGE_COLLECTION=1/ $infainstallerloc/SilentInput.properties

sed -i s/^KEY_DEST_LOCATION=.*/KEY_DEST_LOCATION=$defaultkeylocation/ $infainstallerloc/SilentInput.properties

sed -i s/^PASS_PHRASE_PASSWD=.*/PASS_PHRASE_PASSWD=$(echo $sitekeyKeyword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^SERVES_AS_GATEWAY=.*/SERVES_AS_GATEWAY=1/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_TYPE=.*/DB_TYPE=$dbType/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_UNAME=.*/DB_UNAME=$dbUser/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_PASSWD=.*/DB_PASSWD=$(echo $dbPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_SERVICENAME=.*/DB_SERVICENAME=$dbName/ $infainstallerloc/SilentInput.properties

sed -i s/^DB_ADDRESS=.*/DB_ADDRESS=$dbaddress/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_NAME=.*/DOMAIN_NAME=$domainName/ $infainstallerloc/SilentInput.properties

sed -i s/^NODE_NAME=.*/NODE_NAME=$nodeName/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_PORT=.*/DOMAIN_PORT=$nodePort/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_NODE_NAME=.*/JOIN_NODE_NAME=$nodeName/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_HOST_NAME=.*/JOIN_HOST_NAME=$hostname/ $infainstallerloc/SilentInput.properties

sed -i s/^JOIN_DOMAIN_PORT=.*/JOIN_DOMAIN_PORT=$nodePort/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_USER=.*/DOMAIN_USER=$domainUser/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_HOST_NAME=.*/DOMAIN_HOST_NAME=$domainHost/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_PSSWD=.*/DOMAIN_PSSWD=$(echo $domainPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

sed -i s/^DOMAIN_CNFRM_PSSWD=.*/DOMAIN_CNFRM_PSSWD=$(echo $domainPassword | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/ $infainstallerloc/SilentInput.properties

if [ "$dbType" = "DB2" -a "$dbTablespace" != "#_no_tablespace_#" ]
then
	sed -i s/^DB2_TABLESPACE=.*/DB2_TABLESPACE=$dbType/ $infainstallerloc/SilentInput.properties
fi

# To speed up installation
mv $infainstallerloc/source $infainstallerloc/source_temp
mkdir $infainstallerloc/source
mv $infainstallerloc/unjar_esd.sh $infainstallerloc/unjar_esd.sh_temp
head -1 $infainstallerloc/unjar_esd.sh_temp > $infainstallerloc/unjar_esd.sh
echo exit_value_unjar_esd=0 >> $infainstallerloc/unjar_esd.sh
chmod 777 $infainstallerloc/unjar_esd.sh

echo Installing Informatica domain
cd $infainstallerloc
echo Y Y | sh silentinstall.sh 


# Revert speed up changes
mv $infainstallerloc/source_temp/* $infainstallerloc/source
rm $infainstallerloc/unjar_esd.sh
mv $infainstallerloc/unjar_esd.sh_temp $infainstallerloc/unjar_esd.sh

if [ -f $informaticaopt/license.key ]
then
	rm $informaticaopt/license.key
fi

echo Informatica setup Complete.

cd $infainstallionlocown/10.1.1

# Validate of installation
isp/bin/infacmd.sh ping -dn $domainName -nn $nodeName
if [ $? -ne 0 ] 
then
	echo "Informatica domain setup failed"
	exit 255
fi



# Get license name from domain
licenseNameOption=""
if [ "$infaLicense" != "#_no_license_#" ]
then
	licenseName=`isp/bin/infacmd.sh listLicenses -dn $domainName -un $domainUser -pd $domainPassword | head -1 | awk '{print $1}'`
	licenseNameOption="-ln $licenseName"
	echo $licenseName
fi


if [ $joinDomain -eq 0 ]
then
	
	if [ "$dbType" = "MSSQLServer" ]
	then
		pcrsDBType="MSSQLServer"
		pcrsConnectString="$dbHost@$dbName"
		pcrsTablespace=""

	elif [ "$dbType" = "Oracle" ]
	then
		pcrsDBType="Oracle"
		pcrsConnectString=$dbName
		pcrsTablespace=""

	elif [ "$dbType" = "DB2" ] 
	then
		pcrsDBType="DB2"
		pcrsConnectString=$dbName
		pcrsTablespace="TablespaceName=$dbTablespace" 
	else
		echo Unsupported database
		exit 255
	fi

	
	echo "creating PC services" >> $logfile

	date >> $logfile
    isp/bin/infacmd.sh  createrepositoryservice -dn $domainName -nn $nodeName -sn $pcrsName -so DBUser=$pcrsDBUser DatabaseType=$pcrsDBType DBPassword=$pcrsDBPassword ConnectString=$pcrsConnectString CodePage="ISO 8859-1 Western European"  OperatingMode=NORMAL $pcrsTablespace -un $domainUser -pd $domainPassword $licenseNameOption -sd &>> $logfile
    EXITCODE=$?

    if [ $nodeCount -eq 1 ]
	then
		date >> $logfile
		isp/bin/infacmd.sh  createintegrationservice -dn $domainName -nn $nodeName -un $domainUser -pd $domainPassword -sn $pcisName  -rs $pcrsName  -ru $domainUser -rp $domainPassword -po codepage_id=4 $licenseNameOption -sd &>> $logfile
	   	EXITCODE=$(($? | EXITCODE))
	else 
		date >> $logfile
		isp/bin/infacmd.sh  creategrid -dn $domainName -un $domainUser -pd $domainPassword -gn grid -nl $nodeName &>> $logfile
	  	EXITCODE=$(($? | EXITCODE))

		date >> $logfile
		isp/bin/infacmd.sh  createintegrationservice -dn $domainName -gn grid -un $domainUser -pd $domainPassword -sn $pcisName -rs  $pcrsName -ru $domainUser -rp $domainPassword  -po codepage_id=4 $licenseNameOption -sd &>> $logfile
	  	EXITCODE=$(($? | EXITCODE))

	fi
else
	date >> $logfile
    isp/bin/infacmd.sh  updategrid -dn $domainName -un $domainUser -pd $domainPassword -gn grid -nl $nodeName -ul &>> $logfile
	EXITCODE=$?

	date >> $logfile
    isp/bin/infacmd.sh  updateServiceProcess -dn $domainName -un $domainUser -pd $domainPassword -sn $pcisName -nn $nodeName -po CodePage_Id=4 &>> $logfile
    EXITCODE=$(($? | EXITCODE))
     
fi

echo Changing ownership of directories
chown -R $osUserName $infainstallionlocown
chown -R $osUserName $informaticaopt 
chown -R $osUserName $mountdir
chown -R $osUserName /home/$osUserName

exit $EXITCODE