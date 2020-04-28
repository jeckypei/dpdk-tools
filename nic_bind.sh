#!/bin/bash
# nic_bind.sh -s  , to show all net device#
# nic_bind.sh --bind vfio-pci --force 0000:02:02.0
# nic_bind.sh --bind igb_uio --force 0000:02:02.0
# nic_bind.sh --unbind 0000:02:02.0

#set -x



get_eth_name()
{
        slot=$1
        dir=/sys/bus/pci/devices/$slot/net
        if [ -e $dir ]; then
                name=$(ls $dir);
                echo $name
		else
			echo ""
        fi
}

get_pci_vendor_id()
{
        slot=$1
        filename=/sys/bus/pci/devices/$slot/vendor
        if [ -e $filename ]; then
                name=$(cat $filename | sed 's/0x//');
                echo $name
		else 
			echo ""
        fi
}

get_pci_device_id()
{
        slot=$1
        filename=/sys/bus/pci/devices/$slot/device
        if [ -e $filename ]; then
            name=$(cat $filename | sed 's/0x//');
            echo $name
		else 
			echo ""
        fi
        
}

get_pci_driver_name()
{
        slot=$1
        filename="/sys/bus/pci/devices/${slot}/driver"
        if [ -e $filename ]; then
               name=$(ls -l  $filename | sed 's/.*\///')
               echo $name
		else
			echo ""
        fi
}


#show_status: array NetDevSlotTbl NetDevEthNameTbl NetDevEthDriverTbl
show_status()
{
        let netDevIndex=0
        IFS=$'\n'
        for line in `lspci -Dvmmnnk`
        do
		        firstWord=$(echo $line | awk '{print $1;}')	
                        if  [[ "$firstWord" = "Slot:" ]]; then
                                        slot=$(echo $line | awk '{print $2;}')
                        elif  [[ "$line" =~ "Class" ]]; then
                                        #class=$(echo $line | awk '{print $3;}')
                                        class=$line
                        elif  [[ "$line" =~ "Driver" ]]; then
                                        driver=$(echo $line | awk '{print $2;}')
                                        if [[ $class =~ "0200" ]]; then
                                                        NetDevSlotTbl[$netDevIndex]=$slot
                                                        NetDevEthDriverTbl[$netDevIndex]=$driver
                                                        NetDevEthNameTbl[$netDevIndex]=$(get_eth_name $slot)
                                                        let netDevIndex++
                                        fi
                        fi
        done

        let netDevIndex=0
	echo "Total Net Device Number: ${#NetDevSlotTbl[@]}"
        while [ $netDevIndex -lt ${#NetDevSlotTbl[@]} ]
        do
                echo "Dev $netDevIndex # pci: ${NetDevSlotTbl[$netDevIndex]}, driver: ${NetDevEthDriverTbl[$netDevIndex]}, infName: ${NetDevEthNameTbl[$netDevIndex]}"
                let netDevIndex++
        done

}



unbind_device()
{
	slot=$1
	filename="/sys/bus/pci/devices/${slot}/driver/unbind"
	if [ -f $filename ]; then
		echo -n ${slot} > $filename
	fi
	
}

bind_device()
{
	driver=$1
	slot=$2
	filename="/sys/bus/pci/devices/${slot}/driver"
	if [ -e $filename ]; then 
		devDriver=$(ls -l  $filename | sed 's/.*\///')
	fi
	if [[ "${devDriver}y" == "${driver}y" ]]; then
		echo "Warn: ${driver} has already binded ${slot}, will try to rebind !!! \n"
	fi
	unbind_device $slot
	filename="/sys/bus/pci/devices/${slot}/driver_override"
	if [ -f $filename ]; then
		echo -n $driver > $filename
	else
		filename="/sys/bus/pci/drivers/${driver}/new_id"
		deviceId=$(get_pci_device_id $slot)
		vendorId=$(get_pci_vendor_id $slot)
		echo -n "${vendorId} ${deviceId}" > $filename
	fi

	filename="/sys/bus/pci/drivers/${driver}/bind"
	echo -n "$slot" > $filename

	filename="/sys/bus/pci/devices/${slot}/driver_override"
	if [ -f $filename ]; then
		echo -ne "\x00" > $filename
	fi
}

if [ -z $1 ]; then
	show_status
	exit
fi

#./scripts/nic_bind.sh -s or #./scripts/nic_bind.sh --status
if [[ $1 == "-s" || $1 == "--status" ]]; then
	show_status
	exit
fi

#./scripts/nic_bind.sh --bind igb_uio --force 0000:02:02.0
#./scripts/nic_bind.sh --bind vfio-pci --force 0000:02:02.0
if [[ $1 =~ "-b" || $1 =~ "--bind" ]]; then
	driver=$2
	if [[ $3 =~ "-f" || $1 =~ "--force" ]]; then
		slot=$4
	else
		slot=$3
	fi
	bind_device $driver $slot
	exit
fi

if [[ $1 == "-u" || $1 == "--unbind" ]]; then
	slot=$2
	unbind_device $slot
	exit
fi

