#!/usr/bin/env bash
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
    if [[ "$offset" -lt 0 ]] || [[ "$offset" -gt "$turning_point_500" ]]; then 
    echo -e "${RED}-- Offset value is set to a value that is out of range --${NC}" 2>&1 | tee >> "$scriptLog"
    echo -e "Please change to a value less than $turning_point_500, preferably 200 or less and greater than zero." 2>&1 | tee >> "$scriptLog" exit 1; return; fi

   
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
# requirements: positive or negative number
# purpose: return absolute value of a number
abs() {
echo "$1" | awk ' { if($1>=0) { print $1 } else { print $1*-1 } }'
}

#=======================================================================
# requirements: ƒ"find_adjusted_uid", ƒ"migrate_uid_permissions", global vars "unadjusted_uid", "verified_user_name"
# purpose: down-convert the "unadjusted_uid" and migrate the file permissions
convert_user_uid() {
    local adjusted_uid
   
    # calculate adjusted uid
    adjusted_uid=$( find_readjusted_uid )
    
    # no change - already in range
    if [[ $adjusted_uid -eq $unadjusted_uid ]]; then
    echo -e "- The UID: \"$unadjusted_uid\" is already less than \"$turning_point_500\". No change to the UID is required! -" 2>&1 | tee >> "$scriptLog"; exit; return

    # no change - undefined
    elif [[ "$adjusted_uid" -eq "-1" ]]; then
    echo -e "- The UID: \"$unadjusted_uid\" is \"undefined\". No change to the UID was made! -" 2>&1 | tee >> "$scriptLog"; exit; return

    # no change - blank result, un-handled condition
    elif [[ -z "$adjusted_uid" ]]; then
    echo -e "- The UID: \"$unadjusted_uid\" is an \"un-handled\" condition. No change to the UID was made! -" 2>&1 | tee >> "$scriptLog"; exit; return    
	fi

    ## otherwise condition "michael jackson" - make that change
    ## This "MJ" phase initiates a 3 step chain of commands which must complete or the username and the uid can become disassociated, resulting in files 
    ## still associated with the previous uid and will lead to ownership problems and the result is unhandled by this script.     
    
    # step 1 - change the current uid to the proposed adjusted uid
    #dscl . -change /Users/"$verified_user_name" UniqueID "$unadjusted_uid" "$adjusted_uid";
    
     # step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
    #migrate_uid_permissions "$adjusted_uid"
    
    # step 3 - revert the Hide500Users changes to com.apple.loginwindow
    # condition to hide users below 500
    #hide_users
    
    #    echo -e "Username : \"$verified_user_name\"\tUID : \"$unadjusted_uid\"\t Adjusted UID : \"$adjusted_uid\"" 2>&1 | tee >> "$scriptLog"
}

#=======================================================================
# requirements: 
# purpose: 
revert_user_uid() {
    local adjusted_uid
   
    # calculate adjusted uid
    adjusted_uid=$( find_readjusted_uid )

#     if [[ $unadjusted_uid -gt 500 ]] && [[  $adjusted_uid -lt $(( 500 + offset )) ]]; then
#     echo -e "$currentDate: +- UID already satisfies the range condition -+" 2>&1 | tee >> "$scriptLog"; return;
#     elif ! [[ $adjusted_uid -gt 500 ]] && ! [[  $adjusted_uid -lt $(( 500 + offset )) ]]; then
#     echo -e "$currentDate: ++ The adjusted UID: \"$adjusted_uid\" satisfies the range condition. The proposed UID adjustment satisfies all conditions. ++" 2>&1 | tee >> "$scriptLog"; return;
#     



    ## This next command step initiates a 3 step chain of commands which must complete or the user will be in a corrupt state    
    # step 1 - change the current uid to the proposed adjusted uid
    #dscl . -change /Users/"$verified_user_name" UniqueID "$unadjusted_uid" "$adjusted_uid";
#     else echo -e "$currentDate: -- The adjusted UID failed to satisfy the range condition --" 2>&1 | tee >> "$scriptLog"; return;
#     fi
     
     # step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
    #migrate_uid_permissions "$adjusted_uid"
    
    # step 3 - revert the Hide500Users changes to com.apple.loginwindow
    # condition to uhide users below 500
    #unhide_users
	#     echo -e "Username : \"$verified_user_name\"\tUID : \"$unadjusted_uid\"\t Adjusted UID : \"$adjusted_uid\"" 2>&1 | tee >> "$scriptLog"
}

negative_offset_condition() {
local adjusted_uid=$1
if [[ $offset -le 0 ]]; then 
	if [[ $adjusted_uid -ge 0 ]]; then 
		if [[ $adjusted_uid -lt $turning_point_500 ]]; then 
			echo "Yes"; 
		else echo "No";
		fi
		else echo "No";
	fi
	else echo "No";
fi
return
}

positive_offset_condition() {
local adjusted_uid
adjusted_uid=$(( offset + unadjusted_uid ))

if [[ $offset -gt 0 ]]; then
	echo "offset: $offset"
	echo "adjusted uid: $adjusted_uid"
	
	if [[ $adjusted_uid -gt $turning_point_500 ]]; then
		if [[ $adjusted_uid -le 32767 ]]; then
			echo "$adjusted_uid";
		else echo "-1";
		fi
		else echo "-2";
	fi
	else echo "-3";
fi

}
#=======================================================================
# requirements: ƒ"uid_exists", global vars "unadjusted_uid","offset"
# purpose: returns candidate uid in scope greater than 500 in range of offset.
find_adjusted_uid() {
	echo -e "$currentDate: + [Enter] function call: \"find_adjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
	# vars #
	local adjusted_uid
	local index
	local uid_conflict

	index=0
	uid_conflict="Yes"
	
	adjusted_uid=$(( unadjusted_uid + offset ))

		# if not, then "adjusted_uid" is designated as valid and exit's while loop, returning the valid uid. 
		# if so, increment adjusted_uid and try again in another while loop
	while [[ "$uid_conflict" = "Yes" ]] && [[ "$index" -lt "$( abs "$offset" )" ]]
	do
		# uid									offset	requirement
		# greater than turning point			neg		(( offset + uid  )) >= 0  && (( offset + uid )) <  tp
		# less than or equal to turning point	pos		(( offset + uid )) >  tp && (( offset + uid )) <= 32767
		# * otherwise no change required in all other cases
		# kill loop on no change required


		
		# check to see if uid conflicts with a uid that is in use.
		# if not, then "adjusted_uid" is designated as valid and exit's while loop, returning the valid uid. 
		# if so, increment adjusted_uid and try again on next loop

		uid_conflict=$( uid_exists "$adjusted_uid" )
		
		if [[ "$uid_conflict" != "Yes" ]]; then
		echo $negative_offset_condition
		echo $positive_offset_condition
		if [[ $negative_offset_condition = "Yes" ]] || [[ $positive_offset_condition = "Yes" ]]; then echo "This Meets requir"; return; fi 
		echo -e "$currentDate: + Found valid adjusted UID: \"$adjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
		echo -e "$currentDate: + [Exit] function call: \"find_readjusted_uid\" +" 2>&1 | tee >> "$scriptLog";
		echo -e "$adjusted_uid"
		return
		fi

		(( adjusted_uid++ ));
		(( index++ ))
	done
}



########################################################################
# offset	uid							requirements
# pos		less than turning point		(offset+uid)>tp && (offset+uid)<=32767 		x(0)......x(uid)...x(tp)......x(32767); x(tp) < x(uid+offset) && x(uid+offset)<=x(32767)
# pos		equal to turning point		(offset+uid)>tp && (offset+uid)<=32767		x(0)......[x(uid)=x(tp)]......x(32767); x(tp) < x(uid+offset) && x(uid+offset)<=x(32767)
# pos		greater than turning point	no change required							x(0)......x(tp)...x(uid)......x(32767); no change required b/c uid > tp

# neg		less than turning point		no change required							x(0)......x(uid)...x(tp)......x(32767); no change required b/c uid < tp
# neg		equal to turning point		no change required							x(0)......[x(uid)=x(tp)]......x(32767); no change required b/c uid = tp
# neg		greater than turning point	(offset+uid)>=0 && (offset+uid) < tp		x(0)......x(tp)...x(uid)......x(32767); x(uid+offset)<=x(tp) && x(uid+offset)>x(0)

# zero		less than turning point		no change required							x(0)......x(uid)...x(tp)......x(32767); no change required b/c no offset requirement
# zero		equal to turning point		no change required							x(0)......[x(uid)=x(tp)]......x(32767); no change required b/c no offset requirement
# zero		greater than turning point	no change required							x(0)......x(tp)...x(uid)......x(32767); no change required b/c no offset requirement
########################################################################
# Summary --------------------------------------------------------------
# offset	uid (governing factor)					requirements
# neg		greater than turning point				(( offset + uid  )) >= 0  && (( offset + uid )) <  tp
# pos		less than or equal to turning point		(( offset + uid )) >  tp  && (( offset + uid )) <= 32767
# * otherwise no change required in all other cases

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
# valid="$( validate_user "$username" )"
# echo -e "Valid User - $valid"
# if [[ $valid != "Yes" ]]; then echo -e "Invalid Username. Please only use an \"Account name\" of a user with administrative privileges!"; exit; fi

# # global vars
offset=1;
turning_point_500=2
#verified_user_name="test"
#unadjusted_uid="10"

#positive_offset_condition
# negative_offset_condition 502
# negative_offset_condition 501
# negative_offset_condition 500
# negative_offset_condition 499
# negative_offset_condition 498
# negative_offset_condition 497

for i in {0..4}
do
	unadjusted_uid=$i
	positive_offset_condition $unadjusted_uid
done

# for i in {0..503}
# do
#    negative_offset_condition $i
# done


#find_adjusted_uid


