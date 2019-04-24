#!/usr/bin/env bash
#=======================================================================
# Author:   Spencer Streeter
# Date:     2019.04.02
# Version:  1.0
# About:    Changes UID of admin user account and hides it.
#=======================================================================
#####################################
# functions
#####################################
#=======================================================================
# requirements: unverified username parameter
# purpose: verifies username argument exists
user_name_exists() {
    echo -e "$currentDate: + [Enter] function call: \"user_name_exists\" +" 2>&1 | tee >> "$scriptLog";
    # vars
    local result
    local unverified_user_name
 
    unverified_user_name=$1
   
    ## get exact username not partial match
    result=$(dscl . -list /Users | grep -w "$unverified_user_name";)
    if [[ -n "$result" ]]; then echo "Yes"; else echo "No";fi
    echo -e "$currentDate: + [Exit] function call: \"user_name_exists\" +" 2>&1 | tee >> "$scriptLog";
}
 
#=======================================================================
# requirements: unverified uid parameter	
# purpose: checks if uid argument has already been issued.
uid_exists() {
    echo -e "$currentDate: + [Enter] function call: \"uid_exists\" +" 2>&1 | tee >> "$scriptLog";
    # vars
    local result
    local unverified_uid
    unverified_uid=$1
   
    # get exact user id
    result="$(dscacheutil -q user | grep '^uid:' | grep -w "$unverified_uid" | awk -F ' ' '{print $2}' | head -1)"
    
    # if the result is not blank, then the uid exists
    if [ -n "$result" ]; then echo "Yes"; else echo "No"; fi
    echo -e "$currentDate: + [Exit] function call: \"uid_exists\" +" 2>&1 | tee >> "$scriptLog";
}
 
#=======================================================================
# requirements: username parameter.
# purpose: checks to see if the given user is an admin
isadmin() {
    echo -e "$currentDate: + [Enter] function call: \"isadmin\" +" 2>&1 | tee >> "$scriptLog";
    local result
 
    result=$(id -Gn "$1" | grep -w -o admin;)
    if ! [[ "$result" != "admin" ]]; then echo "Yes"; else echo "No";fi
    echo -e "$currentDate: + [Exit] function call: \"isadmin\" +" 2>&1 | tee >> "$scriptLog";
}

#=======================================================================
# requirements: ƒ"user_name_exists",ƒ"is_admin", unverified username parameter
# purpose: validates global variable "verified_user_name"
validate_user() {
    echo -e "$currentDate: + [Enter] function call: \"validate_user\" +" 2>&1 | tee >> "$scriptLog"
    local result
    local unverified_user_name
 
    unverified_user_name=$1

    # check if the one parameter and only parameter was provided as an argument to the function call
    if (( $# < 1 )); then
    echo -e "$currentDate: -- Username parameter is zero length. --" 2>&1 | tee >> "$scriptLog"; exit 1; return
    else echo -e "$currentDate: ++ Username parameter is at least greater than or equal to 1. ++" 2>&1 | tee >> "$scriptLog"
    fi
    
    if (( $# > 1 ));  then
    echo -e "$currentDate: -- Too many username parameters have been passed --" 2>&1 | tee >> "$scriptLog"; return
    else echo -e "$currentDate: ++ The correct number of username parameters have been passed and are equal to 1. ++" 2>&1 | tee >> "$scriptLog"
    fi
   
    # check if the argument to the function call is constructed of only alphanumeric characters.  
    if [[ $1 = " "* ]] || [[ $1 =~ [^a-zA-Z0-9] ]]; then
    echo -e "$currentDate: -- Please use valid characters as an argument parameter --" 2>&1 | tee >> "$scriptLog"; return;
    else echo -e "$currentDate: ++ Only alphanumeric characters have been submitted as an argument parameter ++" 2>&1 | tee >> "$scriptLog"
    fi
    
    # check that script is run as root
    if [[ $( id -u -r ) -ne 0 ]]; then echo -e "${RED}- This script must be run as root! -${NC}" 2>&1 | tee >> "$scriptLog"; exit 1; return; fi
    
	# check if offset is valid
    if [[ "$offset" -lt 0 ]] || [[ "$offset" -gt "$turning_point" ]]; then 
    echo -e "${RED}-- Offset value is set to a value that is out of range --${NC}" 2>&1 | tee >> "$scriptLog"
    echo -e "Please change to a value less than $turning_point, preferably 200 or less and greater than zero." 2>&1 | tee >> "$scriptLog" exit 1; return; fi

   
    # verify username exists then get user's current id
    result=$( user_name_exists "$unverified_user_name" )
   
    if [[ "$result" != "Yes" ]] ; then
    echo -e "$currentDate: -- User \"$unverified_user_name\" does not exist --" 2>&1 | tee >> "$scriptLog"; return
    fi
   
    verified_user_name="$unverified_user_name";
   
    # check if verified_user_name is admin
    result=$(isadmin "$verified_user_name")
    if [[ "$result" != "Yes" ]]; then
    echo -e "$currentDate: -- User \"$verified_user_name\" is not an admin --" 2>&1 | tee >> "$scriptLog"; return
    else echo -e "$currentDate: ++ User \"$verified_user_name\" is an admin ++" 2>&1 | tee >> "$scriptLog"
    fi
    # return "Yes" for all tests passed
    echo "Yes"
    echo -e "$currentDate: + [Exit] function call: \"validate_user\" +" 2>&1 | tee >> "$scriptLog"; return
    }

#=======================================================================
# requirements: global parameter "verified_user_name"
# purpose: returns the "unadjusted_uid" aka the current uid of the "verified_user_name"
get_user_uid() {
    echo -e "$currentDate: + [Enter] function call: \"get_user_uid\" +" 2>&1 | tee >> "$scriptLog";
    # vars
    local uid
 
    # get uid
    uid=$(dscl . -read "/Users/$verified_user_name" UniqueID | awk -F ' ' '{print $2}');
    echo "$uid"
    echo -e "$currentDate: + [Exit] function call: \"get_user_uid\" +" 2>&1 | tee >> "$scriptLog";
}

#=======================================================================
# requirements: ƒ"uid_exists", global vars "unadjusted_uid","offset", "turning_point"
# purpose: returns available adjusted uid.
find_adjusted_uid() {
	echo -e "$currentDate: + [Enter] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
	# vars #
	local adjusted_uid 
	
	# positive_offset
	if [[ $offset -ge 0 ]]; then
		adjusted_uid="$(( turning_point + 1 ))"
		while [[ "$unadjusted_uid" -le "$turning_point" ]]
		do
			# unadjusted_uid is less than or equal to the turning_point and needs to be incremented; "x(0)...->x(uid)<-...x(tp)...x(32k)" or "x(0)...->x(uid)=x(tp)<-...x(32k)"
			echo -e "Unadjusted UID : $unadjusted_uid is less than or equal to turning_point : $turning_point" 2>&1 | tee >> "$scriptLog";

			# satisfies 1st condition of being greater than the turning_point; "x(0)...x(tp)...->x(adj)<-...x(32k)"
			if [[ "$adjusted_uid" -gt "$turning_point" ]]; then echo -e "Adjusted UID : $adjusted_uid is greater than turning_point : $turning_point" 2>&1 | tee >> "$scriptLog"; uid_conflict=$( uid_exists "$adjusted_uid" );

			# satisfies 2nd condition of being less than or equal to the upper boundary; "x(0)...x(tp)...->x(adj)<-...x(32k) or x(0)...x(tp)......->x(adj)=x(32k)<-
			if [[ "$adjusted_uid" -le "$upper" ]]; then echo -e "Adjusted UID: $adjusted_uid is less than Upper Boundary: $upper" 2>&1 | tee >> "$scriptLog";						

			# if the adjusted uid is not in use, return the value, otherwise increment and try agin
			if [[ "$uid_conflict" != "Yes" ]]; then echo -e "$currentDate: + [Exit] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog"; echo "$adjusted_uid"; return;
			else echo -e "Adjusted UID: $adjusted_uid is in-use -> Increment the Adjusted UID and try again" 2>&1 | tee >> "$scriptLog"; (( adjusted_uid++ )); continue; fi
			else echo -e "Adjusted UID is greater than $upper" 2>&1 | tee >> "$scriptLog"; fi 
			else echo -e "Adjusted UID is less than or equal to $turning_point" 2>&1 | tee >> "$scriptLog"; fi
		done
	fi

	# negative_offset, to change to offset rule, simply modify adjusted_uid="$(( turning_point + offset ))" and (( adjusted_uid++ ))
	if [[ $offset -lt 0 ]]; then
	adjusted_uid="$(( turning_point ))"
		while [[ "$unadjusted_uid" -gt "$turning_point" ]]
		do
			# unadjusted_uid is greater than the turning_point and needs to be decremented
			echo -e "Unadjusted UID : $unadjusted_uid is greater than the turning_point : $turning_point" 2>&1 | tee >> "$scriptLog";			

			# satisfies 1st condition of being less than or equal to the turning_point
			if [[ "$adjusted_uid" -le "$turning_point" ]]; then echo -e "Adjusted UID : $adjusted_uid is less than or equal to the turning_point : $turning_point" 2>&1 | tee >> "$scriptLog"; uid_conflict=$( uid_exists "$adjusted_uid" );
	
			# satisfies 2nd condition of being greater than or equal to the lower boundary
			if [[ "$adjusted_uid" -ge "$lower" ]]; then
			echo -e "Adjusted UID: $adjusted_uid is greater than or equal to the Lower Boundary: $lower" 2>&1 | tee >> "$scriptLog";
	
			# if the adjusted uid is not in use, return the value, otherwise decrement and try agin
			if [[ "$uid_conflict" != "Yes" ]]; then echo -e "$currentDate: + [Exit] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog"; echo "$adjusted_uid"; return;
			else echo -e "Adjusted UID: $adjusted_uid is in-use -> decrement the Adjusted UID and try again" 2>&1 | tee >> "$scriptLog"; (( adjusted_uid-- )); continue; fi
			else echo -e "Adjusted UID is less than $lower" 2>&1 | tee >> "$scriptLog"; fi 
			else echo -e "Adjusted UID is greater than $turning_point" 2>&1 | tee >> "$scriptLog"; fi 
		done
	fi
}


#=======================================================================
# requirements: admin users with uid's set below turning_point 
# purpose: modifies com.apple.loginwindow to hide admin users with uid's below turning_point
hide_users() {
sudo defaults write /Library/Preferences/com.apple.loginwindow Hide500Users -bool YES
}

#=======================================================================
# requirements: admin users with uid's below turning_point. 
# purpose: reverts the hide_users change to com.apple.loginwindow.plist to restore uids to uid's above turning_point so that they can be properly handled as normal accounts.
unhide_users() {
    undo_hide500() { sudo defaults delete /Library/Preferences/com.apple.loginwindow Hide500Users; } 
    result=$(sudo defaults read /Library/Preferences/com.apple.loginwindow | grep Hide500Users)
    if [ -n "$result" ]; then undo_hide500; fi
}


#=======================================================================
# requirements: 
# purpose: 
migrate_user_uid() {
    local adjusted_uid
   
    # calculate adjusted uid
    adjusted_uid=$( find_adjusted_uid )
   
    echo -e "Username : \"$verified_user_name\"\tUID : \"$unadjusted_uid\"\t: \"$adjusted_uid\"";

	## This next command step initiates a 3 step chain of commands which must complete or the user will be in a corrupt state	
	# step 1 - change the current uid to the proposed adjusted uid
    #dscl . -change /Users/"$verified_user_name" UniqueID "$unadjusted_uid" "$adjusted_uid";
 	
 	# step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
    #migrate_uid_permissions "$adjusted_uid"
    
    # step 3 - revert the Hide500Users changes to com.apple.loginwindow
    # condition to uhide users below $turning_point
    #unhide_users
}

#=======================================================================
# requirements: global vars "verified_user_name","unadjusted_uid", parameter"adjusted_uid" aka *new* current uid
# purpose: to hand-off the ownership of links, files and directories of the "unadjusted_uid" to the "adjusted_uid"
migrate_uid_permissions() {
    echo -e "$currentDate: + [Enter] function call: \"migrate_uid_permissions\" +" 2>&1 | tee >> "$scriptLog";
    local adjusted_uid
   
    adjusted_uid=$1
 
    # Change/restore ownership of user's files
    find /Users/"$verified_user_name" -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /Library -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /Applications -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /usr -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /private/var/ -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    echo -e "$currentDate: + [Exit] function call: \"migrate_uid_permissions\" +" 2>&1 | tee >> "$scriptLog";
    
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
#------------------------------------
# Vars
#------------------------------------
# Set color codes (See Reference [4]
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'    # No Color
 
scriptLog="/var/log/hide_admin_user.log"    # Log file
currentDate=$(date "+%a %b %d %I:%M:%S %p\$")
FAIL="${RED}- Fail -${NC}"
PASS="${GRN}- Success -${NC}"
offset=
unadjusted_uid=
unverified_user_name=
username=
valid=
verified_user_name=


# Send stdout to "$scriptLog", and then stderr(2) to stdout(1)
exec 1>> "$scriptLog" 2>&1
echo -e "===================================================="
echo -e "Script: $0"
echo -e "Runtime: $currentDate"
echo -e "===================================================="
 
username=$1
valid="$( validate_user "$username" )"
echo -e "Valid User - $valid"
if [[ $valid != "Yes" ]]; then echo -e "Invalid Username. Please only use an \"Account name\" of a user with administrative privileges!"; exit; fi


# 
# # global vars
offset=100;
turning_point=500
verified_user_name=$username
# convert_user_uid
# if [[ $? -eq 0 ]]; then
# echo -e "${GRN}- Admin User $user_name, was hidden -${NC}"
# else echo  -e "${RED}- User $user_name was not hidden -${NC}"
# fi


# revert_user_uid
# if [[ $? -eq 0 ]]; then
# echo -e "${GRN}- Admin User $user_name, was un-hidden -${NC}"
# else echo  -e "${RED}- User $user_name was not un-hidden -${NC}"
# fi
 
#unhide_users
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
