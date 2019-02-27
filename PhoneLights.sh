#!/bin/sh

#Just a little router script I wrote to turn on some of my Hue lights when I get home (read: connect to the network). Instead of running this 
#script in an infinite loop, it is designed to run between a beginning and an end time. I use Cron to start the script just after the beginning
#time.

#My CRON Job is: 1 18 * * * root /bin/sh /tmp/root/PhoneLights.sh
#This starts running the script at 1 minute after the 18th hour day, or 6:01PM

#This script was designed for DD-WRT routers but I'm sure it could be adapted for Tomato, OpenWRT, etc. It assumes that a file named home.txt 
#exists somewhere on your router. On first run, this file can say nothing. If you telnet/ssh into your router, cd to the directory you would 
#like to put the file just type: touch home.txt

#Note that by default, your router's root folder is stored at /tmp/root but /tmp gets wiped on every reboot so if you can store this script on 
#some persistent storage like a USB drive plugged into your router or JFFS2 storage (if your router supports it), you wont have to reload the 
#script and make a new home.txt file every time your router reboots.

#Note from the author: I've never written in a scripting language before. I actually don't really write code at all. I just wanted my router 
#to do something, so I made it happen. If this doesn't work, or is poorly written, I can't really help you. If it does work for you, then enjoy!

mac="xx:xx:xx:xx:xx:xx" #MAC address of the phone (or other device) you want to enable your lights when it connects
bridge_ip="192.168.1.2" #IP address of your Hue Bridge
dev_hash="YOUR HUE DEVELOPER HASH" #you can generate a hash at http://bridge_ip/debug/clip.conf replace bridge_ip with your bridge ip address.

home_txt_location="/tmp/root" #the location of your home.txt file. Leave in the quotation marks when changing this location.

#time (in minutes) after the script detects your phone has connected or disconnected before it will try again. If you're running in and out of 
#your house a it would be very annoying for the lights to turn on every time. Whatever you enter here is effectively doubled when running in 
#and out because the script wont check to see if you've disconnected from the network until rest_time minutes after you've connected.
#Once it does see you've disconnected, it wont check to see if you've connected again for another rest_time minutes.
rest_time=30

#times between which this script will loop. Input begginning and ending hours in 0-23 format. Where 0 is midnight and 23 is 11PM
begin_at_hour=18
begin_at_minute=0
end_at_hour=6
end_at_minute=0

light_one="5" #You can get the number of your light from the debug API
light_two="7" #Second light to turn on when you get home

#converts beginning and ending times into minutes
begin_at_hour_min=$((begin_at_hour * 60))
begin_at_time=$((begin_at_hour_min + begin_at_minute - 1))
end_at_hour_min=$((end_at_hour * 60))
end_at_time=$((end_at_hour_min + end_at_minute))

#while loop that runs the script continuously
while true
do
	#Gets the current time and stores it so the code can play with it
	current_year=$(date +%Y)
	current_month=$(date +%m)
	current_day=$(date +%d)
	current_date=$current_year$current_month$current_day
	current_hour=$(date +%H)
	current_hour_min=$((current_hour * 60))
	current_minute=$(date +%M)
	current_time=$((current_hour_min + current_minute))
	
	#This script only runs between your beginning and end times. Leave it like this if your beginning hour is after your ending hour, ex. begin 
	#at 6PM end at 6AM. If your beginning and ending hours are during the same day, ex. begin at 5PM end at 11PM, change the || bellow to && 
	if [ $current_time -lt $end_at_time ] || [ $current_time -gt $begin_at_time ]
	then

		#Gets the time home.txt was modified
		file_year=$(ls --full-time $home_txt_location/home.txt | awk '{print substr($6,1,4)}')
		file_month=$(ls --full-time $home_txt_location/home.txt | awk '{print substr($6,6,2)}')
		file_day=$(ls -l $home_txt_location/home.txt | awk '{print $7}')
		file_date=$file_year$file_month$file_day
		file_hour=$(ls -l $home_txt_location/home.txt | awk '{print substr($8,1,2)}')
		file_hour_min=$((file_hour * 60))
		file_minute=$(ls -l $home_txt_location/home.txt | awk '{print substr($8,4,2)}')
		file_time=$((file_hour_min + file_minute))
		
		#checks to see if the last time home.txt was modified was before the current day
		date_check=$((file_date < current_date)) > /dev/null 2>&1
		
		if [ $date_check = 0 ]
		then
			time_difference=$((current_time - file_time))
		else
			time_difference=$((rest_time + 1))
		fi
		
		#checks if the rest_time has elapsed before running the rest of the code
		rest_check=$((time_difference < rest_time))
		
		#if the time difference between code execution and the last edit of the home.txt file is greater than the rest period
		if [ $rest_check = 0 ] 
		then
			if grep -Fq "false" $home_txt_location/home.txt #check if home.txt says false
			then
				if grep -Fq $mac /proc/net/arp #if it is false, check the arp table and see if the mac address of the phone showed up
				then #if the mac is in the arp table, bingo, throw those lights on!
					curl -X PUT -d '{"on":true,"ct":369,"bri":130}' http://$bridge_ip/api/$dev_hash/lights/$light_one/state > /dev/null 2>&1
					curl -X PUT -d '{"on":true,"ct":369,"bri":100}' http://$bridge_ip/api/$dev_hash/lights/$light_two/state > /dev/nul 2>&1
					echo "true" > $home_txt_location/home.txt #now that we know you're home, set the home.txt flag to true
					phone_ip=$(grep -F $mac /proc/net/arp | awk '{print $1}') #gets the ip address assigned to $mac from the arp table
					sleep 5
				fi
			else
				if ping -c 1 $phone_ip &> /dev/null #if the home.txt does not say false ping the phone_ip to see if it's still online
				then
					sleep 5
				else
					echo "false" > $home_txt_location/home.txt #if the ping doesn't make a connection set the home.txt file to false
				fi
			fi
		fi
		sleep 10
	else
		break #if outside of the designated start and end times, break out of the while loop and exit the script
	fi
done
