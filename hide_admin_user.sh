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
    if [[ "$offset" -lt 0 ]] || [[ "$offset" -gt "$range_500" ]]; then 
    echo -e "${RED}-- Offset value is set to a value that is out of range --${NC}" 2>&1 | tee >> "$scriptLog"
    echo -e "Please change to a value less than $range_500, preferably 200 or less and greater than zero." 2>&1 | tee >> "$scriptLog" exit 1; return; fi

   
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
# requirements: global vars "unadjusted_uid","range_500","offset"
# purpose: 
find_uid_range() {
########################################################################
# ranges (a)...|...(b)...|(500)|...(c)...|...(d)
# The offset should not be greater than 200, but when demoting the uid, it must not be greater 
# than 500 (demoting a user from a UID of 500 would make him root (uid = 0 ), which is already in use)
# a larger negative offset than 500 would result in negative UID's, forming a lower boundary condition.
# R(a) { lower boundary} - all values less than ( 500 - offset) 
# R(b) { negative offset }  - all values greater than ( 500 - offset) but less than 500
# R(500) { no man's land - DMZ } - only 500
# R(c) { positive offset } - all values greater than 500 but less than ( 500 + offset )
# R(d) { upper boundary } - greater than ( 500 + offset )
########################################################################
# out of bounds
if [[ "$unadjusted_uid" -lt 0 ]] || [[ "$unadjusted_uid" -gt 32767 ]]; then echo -e "undefined"; return; fi

# range (a) - "unadjusted_uid" <= ( range_500 - offset )
if [[ "$unadjusted_uid" -le $(( range_500 - offset)) ]]; then echo -e "lower_boundary"; return; fi

# range (b) - {( range_500 - offset ) < unadjusted_uid <= 500
if [[ "$unadjusted_uid" -le $range_500 ]] && [[ "$unadjusted_uid" -gt $(( range_500 - offset)) ]]; then echo -e "negative_offset"; return; fi

# range (c)  500 < unadjusted_uid < ( range_500 + offset )
if [[ "$unadjusted_uid" -gt $range_500 ]] && [[ "$unadjusted_uid" -lt $(( range_500 + offset)) ]]; then echo -e "positive_offset"; return; fi 

# range (d) ( range_500 + offset ) <= "unadjusted_uid"
if [[ "$unadjusted_uid" -ge $(( range_500 + offset)) ]]; then echo -e "upper_boundary"; return; fi 

#https://en.wikipedia.org/wiki/User_identifier
# Max UID: linux = 65535; older = 32767
}

#=======================================================================
# requirements: ƒ"uid_exists", global vars "unadjusted_uid","offset"
# purpose: returns an $adjusted_uid candidate value
find_adjusted_uid() {
    echo -e "$currentDate: + [Enter] function call: \"find_adjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
	# vars #
	local adjusted_uid
	local index
	local original_uid
	local uid_conflict
	local uid_range
	
	original_uid=$unadjusted_uid
	index=0
	uid_conflict="Yes"
	
	uid_range="$( find_uid_range )"
	
	case "$uid_range" in

	# range (b), # range (a) - do nothing
	"negative_offset" | "lower_boundary" )
		echo -e "$currentDate: ++ UID: \"$unadjusted_uid\" is already decremented below 500 ++" 2>&1 | tee >> "$scriptLog"
		echo "$unadjusted_uid"; return
		;;
	# range (c) - 1/2 cases that should be migrated
	"positive_offset" )
		echo -e "$currentDate: +- UID: \"$unadjusted_uid\" needs to be decremented to a valid id below 500  -+" 2>&1 | tee >> "$scriptLog"
		;;
	# range (d) - 2/2 cases that should be migrated
	"upper_boundary" )
		echo -e "$currentDate: +- UID: \"$unadjusted_uid\" needs to be decremented to a valid id below 500  -+" 2>&1 | tee >> "$scriptLog"
		# reset uid starting point by convention. 
		original_uid=$(( range_500 + 1 ))
		;;
	# range (undefined) - do nothing
	"undefined" )
		echo -e "$currentDate: +- UID: \"$unadjusted_uid\" is \"undefined\" -+" 2>&1 | tee >> "$scriptLog"; echo "-1"; return
		;;
	* )
		# this condition should never be triggered and is only here for complete coverage
		echo -e "$currentDate: -- This is an un-handled condition --" 2>&1 | tee >> "$scriptLog"; echo ""; return
	esac
	
	# best guess offset for the adjusted_uid under the assumption that the UID is exactly displaced by an offset of 100.
	adjusted_uid=$(( original_uid - offset ))
	while [[ "$uid_conflict" = "Yes" ]] && [[ "$index" -lt "$offset" ]]
	do
		# check to see if uid conflicts with a uid that is in use.
		uid_conflict=$( uid_exists "$adjusted_uid" )
		
		# if not ( uid_conflict="No" ), then "adjusted_uid" is designated as valid and exit's while loop, returning the valid uid.
		if [[ "$uid_conflict" != "Yes" ]]; then
		echo -e "$currentDate: + Found valid adjusted UID: \"$adjusted_uid\" +" 2>&1 | tee >> "$scriptLog"
		echo -e "$currentDate: + [Exit] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog"
		echo -e "$adjusted_uid"
		return
		fi
		
		# if so ( uid_conflict="Yes" ), increment adjusted_uid and try again on next loop
		(( adjusted_uid++ ));
		(( index++ ))
	done
}

#=======================================================================
# requirements: ƒ"uid_exists", global vars "unadjusted_uid","offset"
# purpose: returns candidate uid in scope greater than 500 in range of offset.
find_readjusted_uid() {
	echo -e "$currentDate: + [Enter] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
	# vars #
	local adjusted_uid
	local original_uid
	local index
	local uid_conflict
	local uid_range
	
	original_uid=$unadjusted_uid
	index=0
	uid_conflict="Yes"
	
	uid_range="$( find_uid_range )"
	
	case "$uid_range" in
	# range (a) - 1/2 cases that should be migrated
	"lower_boundary" )
		echo -e "$currentDate: -- UID: \"$unadjusted_uid\" incremented outside acceptable offset range. Resetting UID value (\"$original_uid\") to satisfy range condition --" 2>&1 | tee >> "$scriptLog";
		# reset uid starting point by convention. 
		original_uid=$(( range_500 + 1 - offset ))
		;;
	# range (b) - 2/2 cases that should be migrated
	"negative_offset" )
		echo -e "$currentDate: ++ UID: \"$unadjusted_uid\" needs to be incremented to a valid id above 500 ++" 2>&1 | tee >> "$scriptLog";
		;;
	# range (c), # range (d) - do nothing
	"positive_offset" | "upper_boundary" )
		echo -e "$currentDate: +- UID: \"$unadjusted_uid\" already incremented above 500 -+" 2>&1 | tee >> "$scriptLog"; echo "$unadjusted_uid"; return;
		;;
	# range (undefined) - do nothing
	"undefined" )
		echo -e "$currentDate: +- UID: \"$unadjusted_uid\" is \"undefined\" -+" 2>&1 | tee >> "$scriptLog"; echo "-1"; return;
		;;
	* )
		# this condition should never be triggered and is only here for complete coverage
		echo -e "$currentDate: -- This is an un-handled condition --" 2>&1 | tee >> "$scriptLog"; echo ""; return;
	esac
	
	# set start best guess offset for the adjusted_uid under the assumption that the UID is exactly displaced by an offset of 100.
	adjusted_uid=$(( original_uid + offset ))
		# if not, then "adjusted_uid" is designated as valid and exit's while loop, returning the valid uid. 
		# if so, increment adjusted_uid and try again in another while loop
	while [[ "$uid_conflict" = "Yes" ]] && [[ "$index" -lt "$offset" ]]
	do
		# check to see if uid conflicts with a uid that is in use.
		# if not, then "adjusted_uid" is designated as valid and exit's while loop, returning the valid uid. 
		# if so, increment adjusted_uid and try again on next loop
		uid_conflict=$( uid_exists "$adjusted_uid" )
		
		if [[ "$uid_conflict" != "Yes" ]]; then
		echo -e "$currentDate: + Found valid adjusted UID: \"$adjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
		echo -e "$currentDate: + [Exit] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
		echo -e "$adjusted_uid"
		return
		fi

		(( adjusted_uid++ ));
		(( index++ ))
	done
}


#=======================================================================
# requirements: admin users with uid's set below 500 
# purpose: modifies com.apple.loginwindow to hide admin users with uid's below 500
hide_users() {
sudo defaults write /Library/Preferences/com.apple.loginwindow Hide500Users -bool YES
}

#=======================================================================
# requirements: admin users with uid's below 500. 
# purpose: reverts the hide_users change to com.apple.loginwindow.plist to restore uids to uid's above 500 so that they can be properly handled as normal accounts.
unhide_users() {
    undo_hide500() { sudo defaults delete /Library/Preferences/com.apple.loginwindow Hide500Users; } 
    result=$(sudo defaults read /Library/Preferences/com.apple.loginwindow | grep Hide500Users)
    if [ -n "$result" ]; then undo_hide500; fi
}

#=======================================================================
# requirements: ƒ"find_adjusted_uid", ƒ"migrate_uid_permissions", global vars "unadjusted_uid", "verified_user_name"
# purpose: down-convert the "unadjusted_uid" and migrate the file permissions
convert_user_uid() {
	local adjusted_uid
   
    # calculate adjusted uid #|| [[ -z $adjusted_uid -eq ]]
    adjusted_uid=$(find_readjusted_uid)
	if [[ $adjusted_uid -eq $unadjusted_uid ]]; then
	echo -e "- The UID: \"$unadjusted_uid\" is already less than \"$range_500\". No change to the UID is required! -" 2>&1 | tee >> "$scriptLog"; exit; return
	elif [[ "$adjusted_uid" -eq "-1" ]]; then
	echo -e "- The UID: \"$unadjusted_uid\" is \"undefined\". No change to the UID was made! -" 2>&1 | tee >> "$scriptLog"; exit; return
	elif [[ -z "$adjusted_uid" ]]; then
	echo -e "- The UID: \"$unadjusted_uid\" is an \"un-handled\" condition. No change to the UID was made! -" 2>&1 | tee >> "$scriptLog"; exit; return
	fi
	
    echo -e "Username : \"$verified_user_name\"\tUID : \"$unadjusted_uid\"\t Adjusted UID : \"$adjusted_uid\"" 2>&1 | tee >> "$scriptLog"

	## This next command step initiates a 3 step chain of commands which must complete or the user will be in a corrupt state	
	# step 1 - change the current uid to the proposed adjusted uid
    #dscl . -change /Users/"$verified_user_name" UniqueID "$unadjusted_uid" "$adjusted_uid";
 	
 	# step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
    #migrate_uid_permissions "$adjusted_uid"
    
    # step 3 - revert the Hide500Users changes to com.apple.loginwindow
    # condition to hide users below 500
    #hide_users
}

#=======================================================================
# requirements: 
# purpose: 
revert_user_uid() {
    local adjusted_uid
   
    # calculate adjusted uid
    adjusted_uid=$(find_readjusted_uid)
   
    echo -e "Username : \"$verified_user_name\"\tUID : \"$unadjusted_uid\"\t: \"$adjusted_uid\"";

    # Change user id; Think of someway to accommodate a revert based on a negative offset and current uid below 500
    #### some condition is not being covered here, it has to do with users have been hidden ####
    if [[ $unadjusted_uid -gt 500 ]] && [[  $adjusted_uid -lt $(( 500 + offset )) ]]; then
    echo -e "$currentDate: +- UID already satisfies the range condition -+" 2>&1 | tee >> "$scriptLog"; return;
    elif ! [[ $adjusted_uid -gt 500 ]] && ! [[  $adjusted_uid -lt $(( 500 + offset )) ]]; then
    echo -e "$currentDate: ++ The adjusted UID: \"$adjusted_uid\" satisfies the range condition. The proposed UID adjustment satisfies all conditions. ++" 2>&1 | tee >> "$scriptLog"; return;

	## This next command step initiates a 3 step chain of commands which must complete or the user will be in a corrupt state	
	# step 1 - change the current uid to the proposed adjusted uid
    #dscl . -change /Users/"$verified_user_name" UniqueID "$unadjusted_uid" "$adjusted_uid";
    else echo -e "$currentDate: -- The adjusted UID failed to satisfy the range condition --" 2>&1 | tee >> "$scriptLog"; return;
    fi
 	
 	# step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
    #migrate_uid_permissions "$adjusted_uid"
    
    # step 3 - revert the Hide500Users changes to com.apple.loginwindow
    # condition to uhide users below 500
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
    
    find -xP / -user $adjusted_uid -ls > "remnants-$verified_user_name-$unadjusted_uid.txt"
    # mv /.Trashes/501 /.Trashes/1234
    find -xL / -name "*501" >> "remnants-$verified_user_name-$unadjusted_uid.txt"
    #https://www.inteller.net/notes/change-user-id-on-snow-leopard
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
valid="$( validate_user $username )"
echo -e "Valid User - $valid"
if [[ $valid != "Yes" ]]; then echo -e "Invalid Username. Please only use an \"Account name\"\nof a user with administrative privileges!"; exit; fi

# Testing 123
# 
# # global vars
# offset=100;
# range_500=500
# verified_user_name=$username
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
