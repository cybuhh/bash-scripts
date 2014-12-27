#!/bin/bash

if [ `uname` != 'Darwin' ]; then
	echo 'Sorry this script is for OSX only'
	exit 1
fi

mount_base=/Volumes

# 0 yes
# 1 no
function check_is_mounted_rw {
    mount | grep $1 | grep ntfs | grep -v 'read-only' > /dev/null 2>&1
    return $?
}

function clean_unused_dirs {
	for dir in `find $mount_base -depth 1 -type d 2> /dev/null`; do
		mount | grep $dir > /dev/null 2>&1 || sudo rmdir $dir
	done
}

function mount_partition {
	echo "remount $1"
	mount_result=(`mount | grep /dev/$partition`)
	mount_point=${mount_result[2]}
	# if not defined mount_point get it from volume name
	if [ -z "$mount_point" ]; then
		mount_point=$mount_base/$(diskutil info $1 | grep -Eo "Volume Name:.+?( [^ ]+)" | grep -Eo '[^ ]+$')
	else
		sudo bash -c "umount $1"
	fi
	sudo bash -c "mkdir -p $mount_point && mount -t ntfs -o rw,auto,nobrowse,nodev,nosuid,noowners $1 $mount_point"
	test $? && open $mount_point
}

function mount_all {
	clean_unused_dirs

	## get list of physical disks
	disk_list=`diskutil list | grep /dev/disk`

	## get ntfs partionons for each disk
	for disk in $disk_list; do
	  paritions_list=`diskutil list $disk | grep 'Windows_NTFS' | grep -oE '[^ ]+$'`
	  for partition in $paritions_list; do
	  	mount_device="/dev/$partition"
		check_is_mounted_rw $mount_device
	  	if [ $? != 0  ]; then
	  		mount_partition $mount_device
	  	else
	  		echo "$mount_device - [SKIPPED] Found NTFS partition but currently not mouted in read-only mode"
	  	fi
	  done
	done
}

function umount_all {
    mount_result=(`mount | grep ntfs | grep -v "read-only"`)
    for mount_resource in $mount_result; do
	  	sudo umount ${mount_result[0]}
	 done
}

if [ $# -eq 0 ]; then
	mount_all
else
	if [ "$1" == '-u' ]; then
		if [ $# -eq 1 ]; then
		  	umount_all
		else
			ummount ${@:2}
		fi
	else
		for partition in ${@:1}; do 
			mount_partition $partition
		done
	fi
fi
