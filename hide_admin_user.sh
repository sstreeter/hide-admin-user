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
    # vars
    local result
    local unverifiedUserName
    unverifiedUserName=$1
   
    ## get exact userName not partial match
    result=$(dscl . -list /Users | grep -w "$unverifiedUserName";)
    if [[ -n "$result" ]]; then echo "Yes"; else echo "No";fi
}
 
#=======================================================================
# requirements: unverified uid parameter	
# purpose: checks if uid argument has already been issued.
uidExists() {
    # vars
    local result
    local unverified_uid
    unverified_uid=$1
   
    # get exact user id
    result="$(dscacheutil -q user | grep '^uid:' | grep -w "$unverified_uid" | awk -F ' ' '{print $2}' | head -1)"
    
    # if the result is not blank, then the uid exists
    if [ -n "$result" ]; then echo "Yes"; else echo "No"; fi
}
 
#=======================================================================
# requirements: userName parameter.
# purpose: checks to see if the given user is an admin
isAdmin() {
    local result
    result=$(id -Gn "$1" | grep -w -o admin;)
    if ! [[ "$result" != "admin" ]]; then echo "Yes"; else echo "No";fi
}

#=======================================================================
# requirements: ƒ"userNameExists",ƒ"isAdmin", unverified userName parameter
# purpose: validates global variable "verifiedUserName"
validateUser() {
    local result
    local unverifiedUserName
    unverifiedUserName=$1

    # check if the one parameter and only parameter was provided as an argument to the function call
    if (( $# < 1 )); then
    errormsg+=("validateUser() -> Username is \"<blank>\"."); return
    fi
    
    if (( $# > 1 ));  then
    errormsg+=("validateUser() -> Username is not a valid shortname."); return
    fi
   
    # check if the argument to the function call is constructed of only alphanumeric characters.  
    if [[ $1 = " "* ]] || [[ $1 =~ [^a-zA-Z0-9] ]]; then
	errormsg+=("validateUser() -> Username contains non-alphanumeric characters."); return;
    fi
    
    # check that script is run as root
    if [[ $( id -u -r ) -ne 0 ]]; then echo -e "${RED}- This script must be run as root! -${NC}"; errormsg+=("validateUser() -> Script is not run as \"root\"."); return; fi
   
    # verify userName exists then get user's current id
    result=$( userNameExists "$unverifiedUserName")
   
    if [[ "$result" != "Yes" ]] ; then
    errormsg+=("validateUser() -> Username does not exist."); return
    fi
   
    verifiedUserName="$unverifiedUserName";
   
    # check if verifiedUserName is admin
    result=$(isAdmin "$verifiedUserName")
    if [[ "$result" != "Yes" ]]; then
    errormsg+=("validateUser() -> User is not an \"Admin\".");
    return;
    fi
    	
    # set global userValid flag as  "TRUE" for all tests passed
    userValid=TRUE
    }

#=======================================================================
# requirements: global parameter "verifiedUserName"
# purpose: returns the "unadjusted_uid" aka the current uid of the "verifiedUserName"
getUserUID() {
    # vars
    local uid
 
    # get uid
    uid=$(dscl . -read "/Users/$verifiedUserName" UniqueID | awk -F ' ' '{print $2}');
    echo "$uid"
}

#=======================================================================
# requirements: ƒ"uidExists", global vars "unadjusted_uid","objective", "turning_point"
# purpose: returns available adjusted uid.
findAdjustedUID() {
	# positive offset uid
	trial_adjusted_uid="$adjusted_uid"
	
	if [[ $objective = "showUser" ]]; then
		trial_adjusted_uid="$(( turning_point + 1 ))"
		while [[ "$unadjusted_uid" -le "$turning_point" ]]
		do
			# unadjusted_uid is less than or equal to the turning_point and needs to be incremented; "x(0)...->x(uid)<-...x(tp)...x(32k)" or "x(0)...->x(uid)=x(tp)<-...x(32k)"

			# satisfies 1st condition of being greater than the turning_point; "x(0)...x(tp)...->x(adj)<-...x(32k)"
			if [[ "$trial_adjusted_uid" -gt "$turning_point" ]]; then uid_conflict=$( uidExists "$trial_adjusted_uid");

			# satisfies 2nd condition of being less than or equal to the upper boundary; "x(0)...x(tp)...->x(adj)<-...x(32k) or x(0)...x(tp)......->x(adj)=x(32k)<-
			if [[ "$trial_adjusted_uid" -le "$upper" ]]; then
			# if the adjusted uid is not in use, return the value, otherwise increment and try agin
			if [[ "$uid_conflict" != "Yes" ]]; then adjusted_uid="$trial_adjusted_uid"; return;
			else (( ++trial_adjusted_uid )); continue; fi
			else 
				errormsg+=("findAdjustedUID() -> Adjusted UID is greater than \"$upper\".");
			fi 
			else 
				errormsg+=("findAdjustedUID() -> Adjusted UID is less than or equal to \"$turning_point\".");
				fi
		done
	fi

	# negative offset uid, to change to objective rule, simply modify adjusted_uid="$(( turning_point + objective ))" and (( adjusted_uid++ ))
	if [[ $objective = "hideUser" ]]; then
	trial_adjusted_uid="$(( turning_point ))"
		while [[ "$unadjusted_uid" -gt "$turning_point" ]]
		do
			# unadjusted_uid is greater than the turning_point and needs to be decremented		
			# satisfies 1st condition of being less than or equal to the turning_point
			if [[ "$trial_adjusted_uid" -le "$turning_point" ]]; then uid_conflict=$( uidExists "$trial_adjusted_uid");
	
			# satisfies 2nd condition of being greater than or equal to the lower boundary
			if [[ "$trial_adjusted_uid" -ge "$lower" ]]; then
			# if the adjusted uid is not in use, return the value, otherwise decrement and try agin
			if [[ "$uid_conflict" != "Yes" ]]; then adjusted_uid="$trial_adjusted_uid"; return;
			else (( --trial_adjusted_uid )); continue; fi
			fi 
			fi 
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
    # calculate adjusted uid
    findAdjustedUID
	if [[ -z $adjusted_uid ]]; then echo "Adjusted UID [ NOT FOUND ]. Migration of UID aborted"; return;
	else echo -e "${YLW}[Proposal]:${NC}\t \"$verifiedUserName\":$unadjusted_uid -> $adjusted_uid"; fi

 	if [[ -n $adjusted_uid ]] && [[ -n $unadjusted_uid ]]; then 
 	
	## This next command step initiates a 3 step chain of commands which must complete or the user will be in a corrupt state	
	# step 1 - change the current uid to the proposed adjusted uid
    dscl . -change /Users/"$verifiedUserName" UniqueID "$unadjusted_uid" "$adjusted_uid";
 	
 	# step 2 - migrate owner permissions from current uid to proposed uid. This step makes significant changes, and represents the PoNR aka point of no return
   	migrateUIDPermissions
    
		# step 3 - set preferences 
		# 			showUser - revert the Hide500Users changes to com.apple.loginwindow
		#			hideUser - modifies com.apple.loginwindow to hide admin users with uid's below the turning_point
		# condition to unhide users below $turning_point
		if [[ $objective = "showUser" ]]; then
		unhideUsers
		else
		# condition to hide users below $turning_point
		hideUsers
		fi
	fi
}

#=======================================================================
# requirements: global vars "verifiedUserName","unadjusted_uid", parameter"adjusted_uid" aka *new* current uid
# purpose: to hand-off the ownership of links, files and directories of the "unadjusted_uid" to the "adjusted_uid"
migrateUIDPermissions() {
 
    # Change/restore ownership of user's files
    find /Users/"$verifiedUserName" -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /Library -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /Applications -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    find /usr -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
    # Following directory likely protected by System Integrity Protection (SIP). You will need to do terminal cmd "csrutil disable" on command-R reboot
    #find /private/var/ -user "$unadjusted_uid" -print0 | xargs -0 chown -hf "$adjusted_uid"
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
# requirements: $adjusted_uid, $unadjusted_uid, $userName, turning_point
# purpose: Summarizes expected, final result output and displays errors, if any.
finish() {
local testUID
testUID=$(getUserUID "$userName")
if [[ -n $adjusted_uid ]] && [[ -n $testUID ]]; then 
	echo -e "${YLW}[Expected]->\t${NC} \"$userName\":$unadjusted_uid -> $adjusted_uid"
	echo -e "${YLW}[Result]->\t${NC} \"$userName\":$unadjusted_uid -> $testUID"
	if [[ "$objective" = "showUser" ]]; then
		if [[ "$adjusted_uid" -eq "$testUID" ]] && [[ "$adjusted_uid" -gt "$turning_point" ]]; then echo -e "$PASS"; echo -e "${GRN}- Admin User $userName [VISIBLE] -${NC}"; 
		else echo -e "$FAIL"; echo  -e "${RED}- User \"$userName\":$testUID migration [FAILED] -${NC}"; 
		fi
	elif [[ $objective = "hideUser" ]]; then
		if [[ $adjusted_uid -eq $testUID ]] && [[ $adjusted_uid -le $turning_point ]]; then 
		echo -e "$PASS"; echo -e "${GRN}- Admin User $userName [NOT VISIBLE] -${NC}"; 
		else echo -e "$FAIL"; echo  -e "${RED}- User \"$userName\":$testUID migration [FAILED] -${NC}"; 
		fi
	fi
fi

if [[ -n "${errormsg[*]}" ]]; then
	echo -e "${YLW}--------------------------------------------------${NC}"
	echo -e "${YLW}- Error Messages                                 -${NC}"
	echo -e "${YLW}--------------------------------------------------${NC}"
	i=0;
	for message in "${errormsg[@]}"; do
	echo -e "${YLW}$((++i)). $message ${NC}"
	done
fi

}

#=======================================================================
# requirements: $adjusted_uid, $errormsg, $unadjusted_uid, $userValid
# purpose: resets key values for next username migration
resetVars(){
	adjusted_uid=
	errormsg=()
	unadjusted_uid=
	userValid=FALSE;
	verifiedUserName=
}

#=======================================================================
# requirements: $userName
# purpose: Starts script, validates username, extrapolates UID, requests adjusted uid, and migrates the user.
mainScript() {
############## Begin Script Here ###################
####################################################
# Send stdout to "$logFile", and then stderr(2) to stdout(1)
#exec 1>> "$logFile" 2>&1
echo -e "===================================================="
echo -e "Script:  $scriptName	ver. ${version}"
echo -e "Runtime: $currentDate" 
echo -e "[$globalCount] Objective: $objective -> \"$userName\""
echo -e "===================================================="

echo -e "${YLW}[VERIFY]${NC}\t Username: \"$userName\""
validateUser "$userName"
if [[ $userValid = "TRUE" ]]; then 
echo -e "$PASS ->\t \"$userName\""; 
else errormsg+=("mainScript() -> Username is invalid."); 
echo -e "$FAIL"; finish; return; 
fi
verifiedUserName=$userName

echo -e "${YLW}[Get UID]${NC}\t \"$userName\""
unadjusted_uid=$( getUserUID "$verifiedUserName" )
if [[ -n "$unadjusted_uid" ]]; then echo -e "$PASS ->\t $unadjusted_uid"; else errormsg+=("mainScript() -> UID could not be found."); echo -e "$FAIL"; fi

echo -e "${YLW}[Target]:${NC}\t \"$userName\":$unadjusted_uid"
migrateUserUID
finish
####################################################
############### End Script Here ####################
}

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
currentDate=$(date "+%a %b %d %I:%M:%S %p")
FAIL="${RED}[X] FAIL${NC}"
PASS="${GRN}[√] SUCCESS${NC}"

# global vars
#------------------------------------
upper=32767
lower=0
turning_point=500
globalCount=0
scriptName=$(basename "$0")

userNamearr=("testadmin" "testadmin1" "testadmin2")

objective="showUser"
#objective="hideUser"
echo -e "${GRN}####################################################${NC}"
for user in "${userNamearr[@]}"; do
((++globalCount))
resetVars
userName=$user
mainScript
done

# Reference
# [1] https://stackoverflow.com/questions/6047648/bash-4-associative-arrays-error-declare-a-invalid-option
# [2] https://www.inteller.net/notes/change-user-id-on-snow-leopard
