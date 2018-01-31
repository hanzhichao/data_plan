#!/bin/bash

check_ping()
{
	IP=$1
		ping -c 3 $IP >> /dev/null
		if [ $? -eq 0 ]
			then
				echo 0
		else
			echo 1
				fi
}

internal_distribute()
{
cd /home/simth
rm -rf ./*.log
rm -rf ./ip.internal
rm -rf ./${internal_groupname}_exec.log
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
#"," exclude the instance with more than one internal ip
echo $myline|awk '{print $4"="$12}'|awk -F "," '{print $1}'|awk -F "=" '{print $1" "$3}'>> ip.internal

#echo $myline|awk '{print $12}'|awk -F "," '{print $1}'|awk -F "=" '{print $2}'>> ip.internal
fi
done


cat ./ip.internal|while read myline
do
#internalip=`echo $myline|awk '{print $12}'|awk -F "," '{print $1}'|awk -F "=" '{print $2}'`
internalip=`echo $myline|awk '{print $2}'`
host_name_internal=`echo $myline|awk '{print $1}'`
successfulping=`check_ping $internalip`
#if [ $ping_internalip -eq 0 ];then
if [ $successfulping -eq 0 ];then
echo $host_name_internal pass >>  ./exec.log
echo $host_name_internal pass
expect <<-END2
spawn scp ./timer.sh ./timer.conf exec_script.sh ./internal_copy.sh root@$internalip:/home/simth 
set timeout 30
expect {
#first connect, no public key in ~/.ssh/known_hosts
"Are you sure you want to continue connecting (yes/no)?" {
send "yes\r"
}
#already has public key in ~/.ssh/know_hosts
#"assword:" {
#send "root\r"
#}
}

spawn ssh root@$internalip
#expect "assword:"
#send "root\r"
expect "*"
send "cd /home/simth && ./timer.sh  && crontab -l \r"
expect "*"
send "exit\r"
expect eof
END2


else
echo  $host_name_internal fail >> ./exec.log
echo  $host_name_internal fail
fi


done


grep -rn "StrictHostKeyChecking no" /etc/ssh/ssh_config
if [ $? -eq 0 ];then
echo nothing
else
echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi

scp ./exec.log 15.15.15.13:/tmp/scalability/${internal_groupname}_exec.log

}





internal_distribute 
