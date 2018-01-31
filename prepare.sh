#!/bin/bash
#rm -rf /tmp/scalability
#mkdir /tmp/scalability
#vm_dir=/tmp/scalability

#check all vms in scalability environment with keyworks test/scalbility

new_list_vm()
{
dir="/tmp/scalability"
down_list=`nova hypervisor-list|grep down|awk '{print $4}'`
for i in $down_list
do
echo down host $i >> $dir/down_tmp.log
nova list --host $i >> $dir/down_tmp.log
done
echo ======vms count in down compute, see /tmp/scalabililty/down_tmp.log: `cat $dir/down_tmp.log|awk '{if($4 ~ /^test100*/) print $0;}'|wc` >> $vm_dir/summary.log

up_list=`nova hypervisor-list|grep up|awk '{print $4}'`
for j in $up_list
do
echo up host $j >> $dir/up_tmp.log
nova list --host $j >> $dir/up_tmp.log
done
cat $dir/up_tmp.log|grep ACTIVE|awk '{if($4 ~ /^test100*/) print $0;}' >> $vm_dir/vms.tmp
echo Active vms count in upcompute, see /tmp/scalability/vms.tmp: `cat $vm_dir/vms.tmp|wc` >> $vm_dir/summary.log

cat $dir/up_tmp.log|grep -v ACTIVE|awk '{if($4 ~ /^test100*/) print $0;}' >> $vm_dir/not_active_vms.log
echo None active vms count in upcompute, see /tmp/scalability/not_active_vms.log: `cat $vm_dir/not_active_vms.log|wc` >> $vm_dir/summary.log
}


list_vms()
{
#Save vms to vms.tmp
	nova list|awk '{if($4 ~ /^test100*/) print $0;}' >> $vm_dir/vms.tmp
}

#Group vms according to network
vm_groups()
{
	rm -rf $vm_dir/filter.log
		rm -rf $vm_dir/*.group
				cat $vm_dir/vms.tmp|awk '{print $12}'|awk -F "=" '{print $1}'|sort -u  >> $vm_dir/filter.log 
#collect different vms in diff networks
cat $vm_dir/filter.log |while read filtervms
do
cat $vm_dir/vms.tmp|grep ${filtervms}\= >> $vm_dir/$filtervms.group
done
}

check_ping()
{
IP=$1
ping -c 2 $IP >> /dev/null
if [ $? -eq 0 ]; then
echo 0
else
echo 1
fi
}
associate_floatingip()
{
./delete_resource.sh
rm -rf $vm_dir/serverid_floatingip.log
floatingip_count=`cat $vm_dir/filter.log|wc -l`
echo create_floatingIP_count: $floatingip_count
touch $vm_dir/serverid_floatingip.log
touch $vm_dir/fail_serverid_floatingip.log
for (( i=1; i<=$floatingip_count; i++ ))
do
group_name=`sed -n "${i} p" $vm_dir/filter.log`
vm_count=`cat $vm_dir/$group_name.group|wc -l` 
echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++=
echo $vm_count VM in $group_name, check file $group_name.group for more detail.
echo Assoication floating ip to Instances, Please wait a while
for (( j=1; j<=$vm_count; j++ ))
do
server_id=`sed -n  "${j} p" $vm_dir/$group_name.group|awk '{print $2}'`
#echo server_id: $server_id
server_name=`sed -n "${j} p" $vm_dir/$group_name.group|awk '{print $4}'`
#echo server_name: $server_name
nova show $server_id |grep 15.15.15 &> $vm_dir/tmp.log 

if [ $? -ne 0 ]
then
####################
#Check if floating can be accessed
#Use the vms in group until the floating ip is available
####################
#get floating ip
ip_shouldnotassociate="15.15.15.12 15.15.15.13 15.15.15.165"
floatingip_seg=`nova floating-ip-create Internet |sed -n 4P`
floating_ipaddress=`echo $floatingip_seg |awk '{print $4}'`
floating_id=`echo $floatingip_seg |awk '{print $2}'`

echo $floating_ipaddress
echo $ip_shouldnotassociate | grep "${floating_ipaddress}" >> /dev/null
#echo $netinuse | grep "${array[$expected_concurrency]}" >> temo.log
if [ "$?" -eq 0 ]; then
echo conflict with existing ip
neutron floatingip-delete $floating_id
floating_ipaddress="192.168.xxx.xxx"
fi


#associate floating ip to vm
echo server_id is $server_id $floating_ipaddress
nova floating-ip-associate $server_id  $floating_ipaddress 
successful_associate=`check_ping $floating_ipaddress`
if [ $successful_associate -eq 0 ];then
echo $group_name $server_id $server_name $floating_ipaddress >> $vm_dir/serverid_floatingip.log
echo $group_name======success: $server_id $server_name $floating_ipaddress 
		echo The ${j} instance: $server_name id: $server_id floatingIP:$floating_ipaddress
		break
else
	echo ${group_name}xxxxxxfail: $server_name id: $server_id  floatingIP: $floating_ipaddress
		echo $group_name $server_id $server_name $floating_ipaddress >> $vm_dir/fail_serverid_floatingip.log
		nova floating-ip-disassociate $server_id  $floating_ipaddress
		nova floating-ip-delete $floating_ipaddress
		fi

else
	exsit_ip=`nova floating-ip-list |grep $server_id|awk '{print $4}'`
		successful_associate1=`check_ping $exsit_ip`
		if [ $successful_associate1 -eq 0 ];then
			echo $group_name $server_id $server_name $exsit_ip >> $vm_dir/serverid_floatingip.log 
				echo $group_name=====success: $server_id $server_name $exsit_ip
				echo ExistingIP $j time name: $server_name id:$server_id floatingIP: $exsit_ip
				break
		else
			echo $group_name $server_id $server_name $exsit_ip >> $vm_dir/fail_serverid_floatingip.log
				echo ${group_name}xxxxxxfail: $server_id $server_name $exsit_ip
				echo name: $server_name id: $server_id floatingIP  $exsit_ip failed!
				nova floating-ip-disassociate $server_id  $exsit_ip
				nova floating-ip-delete $floating_ipaddress

				fi

				cat $vm_dir/serverid_floatingip.log|grep $server_id >> /tmp/tmp.log
				if [ $? -ne 0 ]
					then
						if [ $successful_associate1 -eq 0 ];then
							echo $group_name $server_id $server_name $exsit_ip >> $vm_dir/serverid_floatingip.log 
								echo $group_name======success: $server_id $server_name $exsit_ip  
								echo The ${j} name: $server_name id: $server_id floatingIP: $exsit_ip
								break
						else
							echo $group_name $server_id $server_name $exsit_ip >> $vm_dir/fail_serverid_floatingip.log
								echo ${group_namefail}xxxxxxxxxfail:  $server_id $server_name $exsit_ip
								nova floating-ip-disassociate $server_id  $exsit_ip
								nova floating-ip-delete $floating_ipaddress

								fi
								fi

								fi
								done
								done
}

file_transfer()
{
#network1 7cebf7cd-8152-4151-8d50-19eba405dd90 scalability_vm1-1 15.15.15.54
	cat $vm_dir/serverid_floatingip.log|while read myline
		do
			groupname=`echo $myline|awk '{print $1}'`
#echo $groupname
				floatingip=`echo $myline|awk '{print $4}'`
#echo $floatingip 
				rm -rf ./group.name
				echo $groupname |tee  ./group.name
				expect <<-END2
				spawn scp $vm_dir/$groupname.group ./group.name /home/simth/exec_script.sh /home/simth/timer.conf ./internal_disbribute.sh ./internal_copy.sh root@$floatingip:/home/simth 
				set timeout 10000
				expect {
#first connect, no public key in ~/.ssh/known_hosts
					"Are you sure you want to continue connecting (yes/no)?" {
						send "yes\r"
					}
				}

		spawn ssh root@$floatingip
			expect "root@*"
			send "cd /home/simth && ./timer.sh  && hostname && crontab -l && ./internal_disbribute.sh\r"
			expect "*"
			send "exit\r"
			expect eof
			END2
			hostnamevm=`echo $myline|awk '{print $3}'`
				echo ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++=
					done



			}

		main()
		{

				rm -rf /tmp/scalability
				mkdir /tmp/scalability
				vm_dir=/tmp/scalability
				rm -rf /home/simth/master.log
				source /root/openrc
		
				timestap=`date "+%Y_%m_%d_%H_%M_%S"`
				echo start time: $timestap
				new_list_vm
				timestap1=`date "+%Y_%m_%d_%H_%M_%S"`
				echo end time:  $timestap1
				vm_groups


				#associate_floatingip
				file_transfer
		}


		main

