#!/bin/bash

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
host_name=`hostname`
yes_no=`ssh root@15.15.15.165 cat /home/simth/who_will_exec|grep $host_name|awk '{print $2}'`
echo $yes_no

}






main()
{

successful_associate=`check_ping 15.15.15.165`
if [ $successful_associate -eq 0 ];then
yes_no=`check_exec`
echo yes_no $yes_no
if [ "$yes_no" == "yes"  ]; then
echo i will exec 
else
echo i will not exec
fi

crontab /home/simth/timer.conf
fi

}

main
