#!/usr/bin/env bash
#=======================================================================
# Author:   Spencer Streeter
# Date:     2019.04.02
version="1.0"              
# About:    Changes UID of admin user account and hides it.
#=======================================================================
#####################################
# functions
#####################################
#=======================================================================
# requirements: unverified userName parameter
# purpose: verifies userName argument exists
userNameExists() {
    echo -e "$currentDate: ++ [Enter] function call: \"userNameExists\" ++" 2>&1 | tee >> "$logFile";
    # vars
    local result
    local unverifiedUserName
 
    unverifiedUserName=$1
   
    ## get exact userName not partial match
    result=$(dscl . -list /Users | grep -w "$unverifiedUserName";)
    if [[ -n "$result" ]]; then echo "Yes"; else echo "No";fi
    echo -e "$currentDate: ++ [Exit] function call: \"userNameExists\" ++" 2>&1 | tee >> "$logFile";
}
 
#=======================================================================
# requirements: unverified uid parameter	
# purpose: checks if uid argument has already been issued.
uidExists() {
    echo -e "$currentDate: ++ [Enter] function call: \"uidExists\" ++" 2>&1 | tee >> "$logFile";
    # vars
    local result
    local unverified_uid
    unverified_uid=$1
   
    # get exact user id
    result="$(dscacheutil -q user | grep '^uid:' | grep -w "$unverified_uid" | awk -F ' ' '{print $2}' | head -1)"
    
    # if the result is not blank, then the uid exists
    if [ -n "$result" ]; then echo "Yes"; else echo "No"; fi
    echo -e "$currentDate: ++ [Exit] function call: \"uidExists\" ++" 2>&1 | tee >> "$logFile";
}
 
#=======================================================================
# requirements: userName parameter.
# purpose: checks to see if the given user is an admin
isAdmin() {
    echo -e "$currentDate: ++ [Enter] function call: \"isAdmin\" ++" 2>&1 | tee >> "$logFile";
    local result
 
    result=$(id -Gn "$1" | grep -w -o admin;)
    if ! [[ "$result" != "admin" ]]; then echo "Yes"; else echo "No";fi
    echo -e "$currentDate: ++ [Exit] function call: \"isAdmin\" ++" 2>&1 | tee >> "$logFile";
}

#=======================================================================
# requirements: ƒ"userNameExists",ƒ"is_admin", unverified userName parameter
# purpose: validates global variable "verifiedUserName"
validateUser() {
    echo -e "$currentDate: ++ [Enter] function call: \"validateUser\" ++" 2>&1 | tee >> "$logFile"
    local result
    local unverifiedUserName
 
    unverifiedUserName=$1

    # check if the one parameter and only parameter was provided as an argument to the function call
    if (( $# < 1 )); then
    echo -e "$currentDate: -- userName parameter is zero length. --" 2>&1 | tee >> "$logFile"; exit 1; return
    else echo -e "$currentDate: ++ userName parameter is at least greater than or equal to 1. ++" 2>&1 | tee >> "$logFile"
    fi
    
    if (( $# > 1 ));  then
    echo -e "$currentDate: -- Too many userName parameters have been passed --" 2>&1 | tee >> "$logFile"; return
    else echo -e "$currentDate: ++ The correct number of userName parameters have been passed and are equal to 1. ++" 2>&1 | tee >> "$logFile"
    fi
   
    # check if the argument to the function call is constructed of only alphanumeric characters.  
    if [[ $1 = " "* ]] || [[ $1 =~ [^a-zA-Z0-9] ]]; then
    echo -e "$currentDate: -- Please use valid characters as an argument parameter --" 2>&1 | tee >> "$logFile"; return;
    else echo -e "$currentDate: ++ Only alphanumeric characters have been submitted as an argument parameter ++" 2>&1 | tee >> "$logFile"
    fi
    
    # check that script is run as root
    if [[ $( id -u -r ) -ne 0 ]]; then echo -e "${RED}- This script must be run as root! -${NC}" 2>&1 | tee >> "$logFile"; exit 1; return; fi
    
	# check if offset_uid is valid
    if [[ "$offset_uid" -lt 0 ]] || [[ "$offset_uid" -gt "$turning_point" ]]; then 
    echo -e "${RED}-- offset_uid value is set to a value that is out of range --${NC}" 2>&1 | tee >> "$logFile"
    echo -e "Please change to a value less than $turning_point, preferably 200 or less and greater than zero." 2>&1 | tee >> "$logFile" exit 1; return; fi

   
    # verify userName exists then get user's current id
    result=$( userNameExists "$unverifiedUserName" )
   
    if [[ "$result" != "Yes" ]] ; then
    echo -e "$currentDate: -- User \"$unverifiedUserName\" does not exist --" 2>&1 | tee >> "$logFile"; return
    fi
   
    verifiedUserName="$unverifiedUserName";
   
    # check if verifiedUserName is admin
    result=$(isAdmin "$verifiedUserName")
    if [[ "$result" != "Yes" ]]; then
    echo -e "$currentDate: -- User \"$verifiedUserName\" is not an admin --" 2>&1 | tee >> "$logFile"; return
    else echo -e "$currentDate: ++ User \"$verifiedUserName\" is an admin ++" 2>&1 | tee >> "$logFile"
    fi
    	
    # return "Yes" for all tests passed
    echo "Yes"
    echo -e "$currentDate: ++ [Exit] function call: \"validateUser\" ++" 2>&1 | tee >> "$logFile"; return
    }

#=======================================================================
# requirements: global parameter "verifiedUserName"
# purpose: returns the "unadjusted_uid" aka the current uid of the "verifiedUserName"
getUserUID() {
    echo -e "$currentDate: ++ [Enter] function call: \"getUserUID\" ++" 2>&1 | tee >> "$logFile";
    # vars
    local uid
 
    # get uid
    uid=$(dscl . -read "/Users/$verifiedUserName" UniqueID | awk -F ' ' '{print $2}');
    echo "$uid"
    echo -e "$currentDate: ++ [Exit] function call: \"getUserUID\" ++" 2>&1 | tee >> "$logFile";
}

#=======================================================================
# requirements: ƒ"uidExists", global vars "unadjusted_uid","offset_uid", "turning_point"
# purpose: returns available adjusted uid.
findAdjustedUID() {
	echo -e "$currentDate: ++ [Enter] function call: \"findAdjustedUID\" ++" 2>&1 | tee >> "$logFile";
	# vars #
	local adjusted_uid 
	
	# positive_offset_uid
	if [[ $offset_uid -ge 0 ]]; then
		adjusted_uid="$(( turning_point + 1 ))"
		while [[ "$unadjusted_uid" -le "$turning_point" ]]
		do
			# unadjusted_uid is less than or equal to the turning_point and needs to be incremented; "x(0)...->x(uid)<-...x(tp)...x(32k)" or "x(0)...->x(uid)=x(tp)<-...x(32k)"
			echo -e "Unadjusted UID : $unadjusted_uid is less than or equal to turning_point : $turning_point" 2>&1 | tee >> "$logFile";

			# satisfies 1st condition of being greater than the turning_point; "x(0)...x(tp)...->x(adj)<-...x(32k)"
			if [[ "$adjusted_uid" -gt "$turning_point" ]]; then echo -e "Adjusted | UID : $adjusted_uid is greater than turning_point : $turning_point" 2>&1 | tee >> "$logFile"; uid_conflict=$( uidExists "$adjusted_uid" );

			# satisfies 2nd condition of being less than or equal to the upper boundary; "x(0)...x(tp)...->x(adj)<-...x(32k) or x(0)...x(tp)......->x(adj)=x(32k)<-
			if [[ "$adjusted_uid" -le "$upper" ]]; then echo -e "Adjusted UID: $adjusted_uid is less than Upper Boundary: $upper" 2>&1 | tee >> "$logFile";						

			# if the adjusted uid is not in use, return the value, otherwise increment and try agin
			if [[ "$uid_conflict" != "Yes" ]]; then echo -e "$currentDate: ++ [Exit] function call: \"findAdjustedUID\" ++" 2>&1 | tee >> "$logFile"; echo "$adjusted_uid"; return;
			else echo -e "Adjusted UID: $adjusted_uid is in-use -> Increment the Adjusted UID and try again" 2>&1 | tee >> "$logFile"; (( adjusted_uid++ )); continue; fi
			else echo -e "Adjusted UID is greater than $upper" 2>&1 | tee >> "$logFile"; fi 
			else echo -e "Adjusted UID is less than or equal to $turning_point" 2>&1 | tee >> "$logFile"; fi
		done
	fi

	# negative_offset_uid, to change to offset_uid rule, simply modify adjusted_uid="$(( turning_point + offset_uid ))" and (( adjusted_uid++ ))
	if [[ $offset_uid -lt 0 ]]; then
	adjusted_uid="$(( turning_point ))"
		while [[ "$unadjusted_uid" -gt "$turning_point" ]]
		do
			# unadjusted_uid is greater than the turning_point and needs to be decremented
			echo -e "Unadjusted UID : $unadjusted_uid is greater than the turning_point : $turning_point" 2>&1 | tee >> "$logFile";			

			# satisfies 1st condition of being less than or equal to the turning_point
			if [[ "$adjusted_uid" -le "$turning_point" ]]; then echo -e "Adjusted | UID : $adjusted_uid is less than or equal to the turning_point : $turning_point" 2>&1 | tee >> "$logFile"; uid_conflict=$( uidExists "$adjusted_uid" );
	
			# satisfies 2nd condition of being greater than or equal to the lower boundary
			if [[ "$adjusted_uid" -ge "$lower" ]]; then
			echo -e "Adjusted UID: $adjusted_uid is greater than or equal to the Lower Boundary: $lower" 2>&1 | tee >> "$logFile";
	
			# if the adjusted uid is not in use, return the value, otherwise decrement and try agin
			if [[ "$uid_conflict" != "Yes" ]]; then echo -e "$currentDate: ++ [Exit] function call: \"findAdjustedUID\" ++" 2>&1 | tee >> "$logFile"; echo "$adjusted_uid"; return;
			else echo -e "Adjusted UID: $adjusted_uid is in-use -> decrement the Adjusted UID and try again" 2>&1 | tee >> "$logFile"; (( adjusted_uid-- )); continue; fi
			else echo -e "Adjusted UID is less than $lower" 2>&1 | tee >> "$logFile"; fi 
			else echo -e "Adjusted UID is greater than $turning_point" 2>&1 | tee >> "$logFile"; fi 
		done
	fi
}

#=======================================================================
# requirements: admin users with uid's set below turning_point 
# purpose: modifies com.apple.loginwindow to hide admin users with uid's below turning_point
hideUsers() {
sudo defaults write /Library/Preferences/com.apple.loginwindow Hide500Users -bool YES
}

#=======================================================================
# requirements: admin users with uid's below turning_point. 
# purpose: reverts the hideUsers change to com.apple.loginwindow.plist to restore uids to uid's above turning_point so that they can be properly handled as normal accounts.
unhideUsers() {
    undo_hide500() { sudo defaults delete /Library/Preferences/com.apple.loginwindow Hide500Users; } 
    result=$(sudo defaults read /Library/Preferences/com.apple.loginwindow | grep Hide500Users)
    if [ -n "$result" ]; then undo_hide500; fi
}


#=======================================================================
# requirements: 
# purpose: 
migrateUserUID() {
	local adjusted_uid
	
    # calculate adjusted uid
    adjusted_uid=$( findAdjustedUID )
	if [[ -z $adjusted_uid ]]; then echo "Adjusted UID [ NOT FOUND ]. Migration of UID aborted"; return;
	else echo -e "Username : \"$verifiedUserName\" | UID : $unadjusted_uid -> $adjusted_uid"; fi

	## This next command step initiates a 3 step chain of commands which must complete or the user will be in a corrupt state	
	# step 1 - change the current uid to the proposed adjusted uid
    #dscl . -change /Users/"$verifiedUserName" UniqueID "$unadjusted_uid" "$adjusted_uid";
 	
 	# step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
    #migrateUIDPermissions "$adjusted_uid"
    
    # step 3 - revert the Hide500Users changes to com.apple.loginwindow
    # condition to uhide users below $turning_point
    #unhideUsers
}

#=======================================================================
# requirements: global vars "verifiedUserName","unadjusted_uid", parameter"adjusted_uid" aka *new* current uid
# purpose: to hand-off the ownership of links, files and directories of the "unadjusted_uid" to the "adjusted_uid"
migrateUIDPermissions() {
    echo -e "$currentDate: ++ [Enter] function call: \"migrateUIDPermissions\" ++" 2>&1 | tee >> "$logFile";
    local adjusted_uid
   
    adjusted_uid=$1
 
    # Change/restore ownership of user's files
    find /Users/"$verifiedUserName" -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /Library -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /Applications -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /usr -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /private/var/ -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    echo -e "$currentDate: ++ [Exit] function call: \"migrateUIDPermissions\" ++" 2>&1 | tee >> "$logFile";
    
    # find -xP / -user $unadjusted_uid -ls > -print0 | xargs -0 chown -hf "$adjusted_uid"
    # mv /.Trashes/$unadjusted_uid /.Trashes/$adjusted_uid
    # find -xL / -name "*$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    
    #https://www.inteller.net/notes/change-user-id-on-snow-leopard
}

#=======================================================================
# requirements: positive or negative number
# purpose: return absolute value of a number
abs() {
local number
number=$1
echo "$number" | awk ' { if($number>=0) { print $number } else { print $number*-1 } }'
}

#=======================================================================
#####################################
## Main
#####################################

# vars
#------------------------------------
# Set color codes (See Reference [4]
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'    # No Color
logFile="/var/log/hide_admin_user.log"    # Log file
currentDate=$(date "+%a %b %d %I:%M:%S %p")
FAIL="${RED}[X] FAIL${NC}"
PASS="${GRN}[√] SUCCESS${NC}"
# offset_uid=
# unadjusted_uid=
# unverifiedUserName=
# userName=
# valid=
# verifiedUserName=
# upper=
# lower=
# moveUID=
# aboveTurningPoint=
# belowTurningPoint=


# global vars
#------------------------------------
upper=32767
lower=0
aboveTurningPoint=1
belowTurningPoint=-1
turning_point=500
userName=$1

scriptName=$(basename "$0")

# Send stdout to "$logFile", and then stderr(2) to stdout(1)
#exec 1>> "$logFile" 2>&1
echo -e "===================================================="
echo -e "Script:  $(basename "$0")	ver. ${version}"
echo -e "Runtime: $currentDate"
echo -e "===================================================="

echo -e "Username: \"$userName\" ${YLW}[VERIFY]${NC}"
valid="$( validateUser "$userName" )"
if [[ "$valid" = "Yes" ]];then echo -e "$PASS"; else echo -e "$FAIL"; exit; fi
verifiedUserName=$userName

echo -e "Get Current User:\"$userName\" ${YLW}[UID]${NC}"
unadjusted_uid=$( getUserUID $verifiedUserName )
if ! [[ -z "$unadjusted_uid" ]]; then echo -e "$PASS"; else echo -e "$FAIL"; fi

echo -e "Migrate User:\"$userName\" UID:\"$unadjusted_uid\""
migrateUserUID
if [[ $? -eq 0 ]]; then echo -e "$PASS"; echo -e "${GRN}- Admin User $user_name [NOT VISIBLE] -${NC}"; 
else echo -e "$FAIL"; echo  -e "${RED}- User $user_name was [VISIBLE] -${NC}"; fi


# Reference
# [1]   https://stackoverflow.com/questions/1216922/sh-command-exec-21
# [2]   https://unix.stackexchange.com/questions/183125/what-does-1-and-2-mean-in-a-bash-script
# [3]   https://www.inteller.net/notes/change-user-id-on-snow-leopard
# [4] ### Colors ###
# Black    0;30    Dark Gray    1;30
# Red    0;31    Light Red    1;31
# Green    0;32    Light Green   1;32
# Brown/Orange 0;33    Yellow    1;33
# Blue    0;34    Light Blue    1;34
# Purple    0;35    Light Purple  1;35
# Cyan    0;36    Light Cyan    1;36
# Light Gray   0;37    White    1;37
# if cond; then op1; else op2; fi
# [5]   https://apple.stackexchange.com/questions/98775/how-do-you-change-your-uid-in-os-x-mountain-lion
# sudo find / -uid 501
# sudo find / -uid $unadjusted_uid -exec chown -hf $adjusted_uid {} \;
# [6]   https://unix.stackexchange.com/questions/155551/how-to-debug-a-bash-script
# [7]   https://unix.stackexchange.com/questions/145651/using-exec-and-tee-to-redirect-logs-to-stdout-and-a-log-file-in-the-same-time
# [8]   https://www.gnu.org/software/bash/manual/bashref.html#Process-Substitution
# [9]   https://www.gnu.org/software/bash/manual/bashref.html#Redirecting-Standard-Output-and-Standard-Error
# [10]  https://www.gnu.org/software/bash/manual/bashref.html#index-exec
# [11]  https://bash.cyberciti.biz/guide/Perform_arithmetic_operations
 
# 1>> and 2>> are redirections for specific file-descriptors, in this case:
# standard output   (file descriptor 1)
# standard error    (file descriptor 2)
# see Reference [1] & [2]
 
# The symbols \< and \> respectively match the empty string at the beginning and end
# of a word. This script grep's in this fashion to eliminate partial matches.
# grep -w <word> or  grep -nr '\<word\>'

# Continuously monitor log file command
# sudo tail -f /var/log/hide_admin_user.log  

# offset	uid							requirements
# pos		less than turning point		(offset+uid)>tp & (offset+uid)<=32767
# 			equal to turning point		(offset+uid)>tp & (offset+uid)<=32767
# 			greater than turning point	no change required
# neg		less than turning point		no change required
# 			equal to turning point		no change required
# 			greater than turning point	(offset+tp)>=0 & (offset+uid) < tp
# zero		less than turning point		no change
# 			equal to turning point		no change
# 			greater than turning point	no change
