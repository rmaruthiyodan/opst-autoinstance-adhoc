#!/bin/bash

find_image()
{
	
#	CENTOS_65="CentOS 6.5 (imported from old support cloud)"
	CENTOS_6="CentOS 6.6 (Final)"
	CENTOS_7="CentOS 7.0.1406"
#	UBUNTU_1204="Ubuntu 12.04"
#	UBUNTU_1404="Ubuntu 14.04"
#	SLES11SP3="SLES 11 SP3"

		
	req_os_distro=$(echo $OS | awk -F"[0-9]" '{print $1}'| xargs| tr '[:lower:]' '[:upper:]')
	req_os_ver=$(echo $OS | awk -F"[a-z]" '{$1="";print $0}'|awk -F '.' '{print $1$2}'| xargs| tr '[:lower:]' '[:upper:]')
	req_os_distro=$req_os_distro\_$req_os_ver
	eval req_os_distro=\$$req_os_distro
	if [ -z req_os_distro ]
	then
		echo -e "\nThe mentioned OS image is unavailable. The available images are:"
		glance image-list
		exit 1
	fi

	image_id=`glance image-list | grep "$req_os_distro" | cut -d "|" -f2,3 | xargs`
	echo $image_id

}

find_netid()
{
	echo $(neutron net-list | head -n 4 | tail -n1| cut -d"|" -f2 | xargs) 
}

find_flavor()
{
	nova flavor-list | grep -q "$FLAVOR_NAME"
	if [ $? -ne 0 ]
	then
		echo "Incorrect FLAVOR_NAME Set. The available flavors are:"
		nova flavor-list
		exit
	fi
	echo $FLAVOR_NAME

}


boot_clusternodes()
{
	for HOST in `grep -w 'HOST[0-9]*' $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
	{
		echo "Creating Instance $HOST"
        	nova boot --image $IMAGE_NAME  --key-name $KEYPAIR_NAME  --flavor $FLAVOR --nic net-id=$NET_ID $HOST > /dev/null 2>&1
	}
}

check_for_duplicates()
{
	echo "Checking for duplicate hostnames"
	existing_nodes=`nova list | awk -F '|' '{print $3}' | xargs`

	for HOST in `grep -w 'HOST[0-9]*' $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
        do
		echo $existing_nodes | grep -q -w $HOST
		if [ $? -eq 0 ]
		then
			echo "An Instance with the name \"$HOST\" already exists. Please choose unique Hosnames"
			exit 1
		fi
	done
	echo "...OK"
		
}

check_vm_state()
{
	echo "Waiting for all the VMs to be started"
	STARTUP_STATE=0
	echo > /tmp/hosts
	STARTED_VMS=""
	for HOST in `grep -w 'HOST[0-9]*' $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
	do
		while [ $STARTUP_STATE -ne 1 ]
        	do
			echo "$STARTED_VMS" | grep -w -q $HOST
			if [ "$?" -ne 0 ]
			then
				vm_info=`nova show $HOST | egrep "vm_state|PROVIDER_NET network"`
				#echo $HOST ":" $vm_info
				echo $vm_info | grep -q -w 'active'
				if [ "$?" -ne 0 ]
				then
					STARTUP_STATE=0
					echo "The VM ($HOST) is still in State [`echo $vm_info | awk -F '|' '{print $3}'`]. Sleeping for 5s..."
					sleep 5
					continue
				fi
			else
				STARTUP_STATE=1
				break
			fi
			IP=`echo $vm_info | awk -F'|' '{print $6}' | xargs`
			echo $IP  $HOST.$DOMAIN_NAME $HOST >> /tmp/hosts
			STARTUP_STATE=1
			STARTED_VMS=$STARTED_VMS:$HOST
			echo "$HOST Ok"
		done
		STARTUP_STATE=0
	done
}

populate_hostsfile()
{
	sort /tmp/hosts | uniq > /tmp/hosts1
	sudo sh -c "cat /tmp/hosts1 >> /etc/hosts"
}

#set -x
LOC=`pwd`
CLUSTER_PROPERTIES=$1
source $LOC/$CLUSTER_PROPERTIES 2>/dev/null

echo "Finding the required Image"
IMAGE_NAME=$(find_image)
echo "Selected Image:" $IMAGE_NAME
IMAGE_NAME=`echo $IMAGE_NAME| cut -d '|' -f1 | xargs`

FLAVOR=`find_flavor`
NET_ID=$(find_netid)
echo "Selected Network: $NET_ID"
echo "Selected Flavor: $FLAVOR"

check_for_duplicates
boot_clusternodes

check_vm_state
populate_hostsfile
./setup_cluster.sh $CLUSTER_PROPERTIES
