#!/bin/sh
#Note from the author: There's definitely a better way to do this but this is my first ever bash script and the first project I've ever made publically available
#This script is designed to run on a DD-WRT router. Note that /tmp gets wiped on every reboot so if you can set up persistent storage, you should.

#Enter the MAC address of the device you want to turn on a light
mac="xx:xx:xx:xx:xx:xx"

#Creates a string named home that contains the word false. Probably a better way to do this but it works
home="false"

#checks to see if home.txt contains the word false
if grep -Fq $home /tmp/root/home.txt
then
	if grep -Fq $mac /proc/net/arp #If home.txt contains false, check the arp table to see if it contains the MAC address and if it does
		then #send request to bridge to turn the light on and set its color and brightness
			#you must change hue_bridge_ip to the ip of your bridge
			#you must change hue_bridge_access_hash to the hash you received through the Hue debug/clip.html
			#you must change number_of_light_you_want to the number of the light you want to turn on. This can be accessed through the Hue debug/clip.html
			curl -X PUT -d '{"on":true,"ct":369,"bri":130}' http://hue_bridge_ip/api/hue_bridge_access_hash/lights/number_of_light_you_want_on/state > /dev/null 2>&1
			echo "true" > /tmp/root/home.txt #change home.txt to say true instead of false
	fi
elif grep -Fq $mac /proc/net/arp #checks arp table to see if MAC is still connected
then
	:
else #if home.txt doesn't contain false but the arp table says the MAC is no longer online set home.txt to false
	echo "false" > /tmp/root/home.txt
fi