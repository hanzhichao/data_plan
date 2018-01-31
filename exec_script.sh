#!/bin/bash
test_dir=/home/simth/scalability


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


check_exec()
{
hostname_simth_ori=`hostname`
#echo $hostname
#ssh root@15.15.15.165 cat /home/simth/who_will_exec|grep -i $host_name|awk '{print $2}'
hostname_simth=`echo $hostname_simth_ori|awk -F "." '{print $1}'`
#Check this vm can exec or not from check server 10.100.211.100(15.15.15.165)
ssh root@15.15.15.165 cat /home/simth/who_will_exec|grep -i "\<$hostname_simth\>"|awk '{print $2}'
#ssh root@15.15.15.165 cat /home/simth/who_will_exec|grep -i "\<test100-H2-10\>"|awk '{print $2}'
#echo $yes_no

}
check_frequency()
{

hostname_simth_ori=`hostname`
#echo $hostname
#ssh root@15.15.15.165 cat /home/simth/who_will_exec|grep -i $host_name|awk '{print $2}'
hostname_simth=`echo $hostname_simth_ori|awk -F "." '{print $1}'`
#Check this vm can exec or not from check server 10.100.211.100(15.15.15.165)
exec_frequency=`ssh root@15.15.15.165 cat /home/simth/exec_frequency|grep -i "\<$hostname_simth\>"|awk '{print $2}'`
#ssh root@15.15.15.165 cat /home/simth/who_will_exec|grep -i "\<test100-H2-10\>"|awk '{print $2}'
#echo $yes_no
echo "*/$exec_frequency * * * * /home/simth/exec_script.sh" > /home/simth/timer.conf
echo "*/$exec_frequency * * * * /home/simth/internal_copy.sh" >> /home/simth/timer.conf
./timer.sh
}


function_load_ELK()
{
ps aux|grep logstash|grep opt >> /tmp/tmp
if [ $? -ne 0 ];then
/opt/logstash/bin/logstash -f /home/simth/logstashconfig/simthels_fio_send.conf &
sleep 10
fi
}

function_vm_load()
{

rm -rf /home/simth/scalability
mkdir -p $test_dir
sleep 1
#localip=`ifconfig eth0|grep inet|sed -n 1p|awk '{print $2}'` 
current_time=`date "+%Y_%m_%d_%H_%M_%S"`
#hard_disk=`fdisk -l|grep Disk|sed -n 1p|awk '{print $2$3$5$6}'`
host_name=`hostname`
index_elk=`cat ./group.name`

#urandom 函数会密集调用cpu资源，生存的随机内容写入hello文件，大小100M左右
#echo  $localip $hard_disk>> $test_dir/disk_ip.log


time dd if=/dev/urandom of=$test_dir/hello bs=10M count=10 oflag=direct
if [ $? -eq 0 ]; then
echo $index_elk $host_name $current_time dd_urandom_100MB created successfully >> $test_dir/dd_urandom.log
else
echo $index_elk $host_name $current_time dd_urandom_100MB created fail >> $test_dir/dd_urandom.log
fi
sleep 1
time dd of=/dev/null if=$test_dir/hello bs=10M count=10 iflag=direct
if [ $? -eq 0 ]; then
echo $index_elk $host_name $current_time dd_null_100MB_created_successfully >> $test_dir/dd_null.log
else
echo $index_elk $host_name $current_time  dd_null_100MB_created_fail >> $test_dir/dd_null.log
fi
./fio --filename=$test_dir/hello  --direct=1 --rw=randwrite --bs=4k --size=10M --numjobs=10 --runtime=20 --name=file1 --ioengine=aio --iodepth=32 --group_reporting |tee $test_dir/fio_randwrite_4k_result
sleep 1
cat $test_dir/fio_randwrite_4k_result|while read myline
do
echo $myline|grep  iops
if [ $? -eq 0 ]; then
echo $index_elk ${host_name} ${current_time}$myline |tee  $test_dir/fio_randwrite_4k_result.log
fi
done
./fio --filename=$test_dir/hello  --direct=1 --rw=randread  --bs=4k --size=10M --numjobs=10 --runtime=20 --name=file1 --ioengine=aio --iodepth=32 --group_reporting |tee $test_dir/fio_randread_4k_result
sleep 1
cat $test_dir/fio_randread_4k_result|while read myline
do
echo $myline|grep  iops
if [ $? -eq 0 ];then
echo $index_elk  ${host_name} ${current_time} $myline |tee  $test_dir/fio_randread_4k_result.log
fi
done
}


function_compute()
{
multiplier1=`echo $RANDOM`
multiplier2=`echo $RANDOM`
echo $multiplier1
echo $multiplier2
let "product=$multiplier1 * $multiplier2"
echo $multiplier1 x $multiplier2 = $product tag_simth >> /tmp/rally_scalability/test.txt

}

function_check_ifprime()
{
	current_date=`date "+%Y_%m_%d_%H_%M_%S"`
		echo current_date is: $current_date
		final_number=`tail -1 /tmp/rally_scalability/test.txt|awk '{print $5}'`
		if [ -z $final_number ];then
			echo Usage:$0 num
				exit 0
				fi
				for (( i=2; i<=$final_number;i++ ));do 
					flag=0;
	for (( j=2;j<=i/2;j++ )); do  
		if ((i%j==0));then
			flag=1;
	echo == $i $j
		break;  
	fi  
		done
		done
		if (($flag));then
			echo $N is not a prime number;
		else
			echo $N is a prime number;
	fi
		end_date=`date "+%Y_%m_%d_%H_%M_%S"`
		echo end_date is: $end_date
}


main()
{

cd /home/simth
exec_script=`cat /home/simth/timer.conf|grep script|awk '{print $1$2$3$4$5}'`
scp_script=`cat /home/simth/timer.conf|grep internal|awk '{print $1$2$3$4$5}'`


current_time=`date "+%Y_%m_%d_%H_%M_%S"`
successful_associate=`check_ping 15.15.15.165`
if [ $successful_associate -eq 0 ];then

grep -rn "StrictHostKeyChecking no" /etc/ssh/ssh_config
if [ $? -eq 0 ];then
echo nothing
else
echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi


yes_no=`check_exec`

echo yes_no $yes_no
if [ "$yes_no" == "yes"  ]; then
echo i will exec 
hostname_toexec=`hostname`
mac_add=`ip a |grep  ether|awk '{print $2}'`
#echo $hostname_toexec
#modify exec frency
check_frequency
ssh root@15.15.15.165 "echo $current_time $hostname_toexec $mac_add exec_${exec_script} scp_${scp_script} >> /tmp/hostname_toexec.log"
function_load_ELK
function_vm_load
else
echo i will not exec
fi

fi

}

#check_exec
main
