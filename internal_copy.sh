#! /bin/bash

check_ping()
{
	IP=$1
		ping -c 2 $IP >> /dev/null
		if [ $? -eq 0 ]
			then
				echo 0
		else
			echo 1
				fi
}

internal_copy()
{
cd /home/simth
rm -rf ./*.log
rm -rf ./ip.internal1
ip_count=0
host_name=`hostname`
#get groupname to avoid other *.group
internal_groupname=`cat ./group.name`
##if do not use this it will copy the files to myown too
# filter the ip(first internal ip in vm)address and name
cat ./$internal_groupname.group| while read myline
do
echo $myline|grep 15.15.15
if [ $? -eq 0 ];then
echo vm with floatingip 1>/dev/null
else
echo $myline|awk '{print $12}'|awk -F "," '{print $1}'|awk -F "=" '{print $2}'>> ip.internal1
fi
done

ls -l|grep ip.internal1
if [ $? -ne 0 ];then
echo no internal vm in this network 
else

cat ./ip.internal1|while read myline
do
let "ip_count++"
echo ip_count is: $ip_count
internalip=$myline
successfulping=`check_ping $internalip`
#if [ $ping_internalip -eq 0 ];then
if [ $successfulping -eq 0 ];then
echo  ${internal_groupname}===================success: $internalip 
echo $internalip >>  ./success_ip.log
expect <<-END2
spawn scp /home/simth/fio root@$internalip:/home/simth/hello.log 
set timeout 100
expect {
#first connect, no public key in ~/.ssh/known_hosts
"*Are you sure you want to continue connecting (yes/no)?" {
send "yes\r"
}
}

END2
echo $internal_groupname $host_name  scp file to the destination $internalip successfully >> /home/simth/scalability/scp.log

else
echo  $internalip >> ./fail_ip.log
echo ${internal_groupname}xxxxxxxxxxxxxxxxxxxxx  fail: $internalip
fi
done
fi
}





internal_copy
