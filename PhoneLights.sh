#!/bin/sh

#Just a little router script I wrote to turn on some of my Hue lights when I get home (read: connect to the network). Instead of running this 
#script in an infinite loop, it is designed to run between a beginning and an end time. I use Cron to start the script just after the beginning
#time.

#My CRON Job is: 1 18 * * * root /bin/sh /tmp/root/PhoneLights.sh
#This starts running the script at 1 minute after the 18th hour day, or 6:01PM
#I set this a minute after my decalred begin_at_hour bellow just to be safe but it should work either way

#This script was designed for DD-WRT routers but I'm sure it could be adapted for Tomato, OpenWRT, etc. This script will create a .txt file
#named home.txt on your router in a folder you specify bellow. This file tells the script the last time your phone connected to or disconnected
#from the router. This prevents the script from turning on your lights if you recently connected or disconnected.
 
#NOTE: By default, your router's root folder is stored at /tmp/root but /tmp gets wiped on every reboot so if you can store this script on 
#some persistent storage like a USB drive plugged into your router or JFFS2 storage (if your router supports it), you wont have to reinstall the 
#script and make a new home.txt file every time your router reboots.

#From the author: Thanks for checking out my script! I've never written in a scripting language before. I actually don't really write code at all. I just 
#wanted my router to do something, so I made it happen. If this doesn't work, or is poorly written, I can't really help you. If it does work for you, then enjoy!

mac="xx:xx:xx:xx:xx:xx" #MAC address of the phone (or other trigger device) you want to enable your lights when it connects to the router
bridge_ip="192.168.1.2" #IP address of your Hue Bridge
dev_hash="YOUR_HUE_DEVELOPER_HASH" #you can generate a hash at http://bridge_ip/debug/clip.conf replace bridge_ip with your bridge ip address.

home_txt_location="/tmp/root" #the location on your router where this script will store home.txt

#time (in minutes) after the script detects your phone has connected or disconnected before it will try again. If you're running in and out of 
#your house a it would be very annoying for the lights to turn on every time. Whatever you enter here is effectively doubled when running in 
#and out because the script wont check to see if you've disconnected from the network until rest_time minutes after you've connected.
#Once it does see you've disconnected, it wont check to see if you've connected again for another rest_time minutes.
rest_time=30

#times between which this script will loop. Input begginning and ending hours in 0-23 format. Where 7 or 07 is 7AM and 23 is 11PM
#this script is set up for your begin hour to be later than your end hour. Unless you change it, it is set to run between 6PM and 8AM
#in the time zone your router is set to. If you would like the start time to be before the end time, like 5PM-11PM, see the notes on lines 87 and 88
begin_at_hour=18
begin_at_minute=00
end_at_hour=7
end_at_minute=00

light_one="1" #You can get the number of your light from the debug API
light_two="2" #Second light to turn on when you get home

#Edit from here down at your own risk

#makes sure rest_time is in decimal and not octal format
rest_time=$(echo $rest_time | awk '{print ($1".")+0}')

#converts beginning and ending times to decimal and then to minutes
begin_at_hour=$(echo $begin_at_hour | awk '{print ($1".")+0}')
begin_at_minute=$(echo $begin_at_minute | awk '{print ($1".")+0}')
end_at_hour=$(echo $end_at_hour | awk '{print ($1".")+0}')
end_at_minute=$(echo $end_at_minute | awk '{print ($1".")+0}')
begin_at_hour_min=$((begin_at_hour * 60))
begin_at_time=$((begin_at_hour_min + begin_at_minute - 1))
end_at_hour_min=$((end_at_hour * 60))
end_at_time=$((end_at_hour_min + end_at_minute))

#checks to see if file home.txt exists in home_txt_location. If not, it creates one.
if [ ! -f $home_txt_location/home.txt ]
then
	echo "false" > $home_txt_location/home.txt
fi

#checks to see if you're on the network before starting loop
#this prevents the lights from coming on if you are already connected at script execution
if grep -Fq $mac /proc/net/arp
then
	phone_ip=$(grep -F $mac /proc/net/arp | awk '{print $1}') #gets the local ip of the trigger device to ping later
	echo "true" > $home_txt_location/home.txt
fi

#while loop that runs the script continuously
while true
do
	#Gets the current time and stores it so the code can play with it
	current_year=$(date +%Y)
	current_month=$(date +%m)
	current_day=$(date +%d)
	current_date=$current_year$current_month$current_day
	current_hour=$(date +%-H)
	current_hour_min=$((current_hour * 60))
	current_minute=$(date +%-M)
	current_time=$((current_hour_min + current_minute))
	
	#This script only runs between your beginning and end times. If your begin_at_time and end_at_time are on the same day
	#Ex. begin at 5PM, end at 11PM, change the || in the line bellow to &&
	if [ $current_time -lt $end_at_time ] || [ $current_time -gt $begin_at_time ]
	then
		#Gets the time home.txt was modified
		file_year=$(ls --full-time $home_txt_location/home.txt | awk '{print substr($6,1,4)}')
		file_month=$(ls --full-time $home_txt_location/home.txt | awk '{print substr($6,6,2)}')
		file_day=$(ls -l $home_txt_location/home.txt | awk '{print $7}')
		file_date=$file_year$file_month$file_day
		file_hour=$(ls -l $home_txt_location/home.txt | awk '{print substr($8,1,2".")+0}')
		file_hour_min=$((file_hour * 60))
		file_minute=$(ls -l $home_txt_location/home.txt | awk '{print substr($8,4,2".")+0}')
		file_time=$((file_hour_min + file_minute))
		
		#checks to see if the last time home.txt was modified was before the current day
		date_check=$((file_date < current_date)) > /dev/null 2>&1
		
		if [ $date_check = 0 ]
		then
			time_difference=$((current_time - file_time))
			time_compare=$((time_difference + 1))
		else
			time_compare=$((rest_time + 1))
		fi
		
		#checks if the rest_time has elapsed before running the rest of the code
		rest_check=$((time_compare > rest_time))
		
		#if the time difference between code execution and the last edit of the home.txt file is greater than the rest period
		if [ $rest_check = 1 ] 
		then
			if grep -Fq "false" $home_txt_location/home.txt #check if home.txt says false
			then
				if grep -Fq $mac /proc/net/arp #if it is false, check the arp table and see if the mac address of the phone showed up
				then #if the mac is in the arp table, bingo, throw those lights on!
					curl -X PUT -d '{"on":true,"ct":369,"bri":130}' http://$bridge_ip/api/$dev_hash/lights/$light_one/state > /dev/null 2>&1
					curl -X PUT -d '{"on":true,"ct":369,"bri":100}' http://$bridge_ip/api/$dev_hash/lights/$light_two/state > /dev/nul 2>&1
					echo "true" > $home_txt_location/home.txt #now that we know you're home, set the home.txt flag to true
					phone_ip=$(grep -F $mac /proc/net/arp | awk '{print $1}') #gets the local ip address assigned to $mac from the arp table
				else
					sleep 15
				fi
			else
				if ping -c 1 $phone_ip &> /dev/null #ping the phone_ip to see if it's still online
				then
					sleep 15
				else
					echo "false" > $home_txt_location/home.txt #if the ping doesn't make a connection set the home.txt file to false
				fi
			fi
		else #if the rest_time has not elapsed, the script will sleep until it has elapsed then check to see if you're online
			sleep_time=$((rest_time - time_difference))
			sleep_time_sec=$((sleep_time * 60))
			sleep $sleep_time_sec
			if grep -Fq $mac /proc/net/arp
			then
				phone_ip=$(grep -F $mac /proc/net/arp | awk '{print $1}') #gets the local ip of the trigger device to ping later
				if grep -Fq "false" $home_txt_location/home.txt #if the home.txt said false, change it to true
				then
					echo "true" > $home_txt_location/home.txt
					rest_time_sec=$((rest_time * 60))
					sleep $rest_time_sec
				fi
			fi
		fi
	else
		#resets home.txt to false when script completes so that you do not have to wait out the rest_time the next time it runs
		echo "false" > $home_txt_location/home.txt
		break #if outside of the designated start and end times, break out of the while loop and exit the script
	fi
done
