#!/usr/bin/env bash
#=======================================================================
# requirements: unverified uid parameter	
# purpose: checks if uid argument has already been issued.
uid_exists() {
    #echo -e "$currentDate: + [Enter] function call: \"uid_exists\" +" 2>&1 | tee >> "$scriptLog";
    # vars
    local result
    local unverified_uid
    unverified_uid=$1
   
    # get exact user id
    result="$(dscacheutil -q user | grep '^uid:' | grep -w "$unverified_uid" | awk -F ' ' '{print $2}' | head -1)"
    
    # if the result is not blank, then the uid exists
    if [ -n "$result" ]; then echo "Yes"; else echo "No"; fi
    #echo -e "$currentDate: + [Exit] function call: \"uid_exists\" +" 2>&1 | tee >> "$scriptLog";
}

find_adjusted_uid() {
local adjusted_uid 

# a positive offset is redefined as any available value between the turning_point and up to 
# and including the upper least common limit (32767) and instead of jumping to an arbitrarily 
# defined offset, it starts at the value immediately following the turning_point and 
# increments the uid until a uid conflict does not exist.
if [[ $offset -ge 0 ]]; then
	adjusted_uid="$(( turning_point + 1 ))"
	while [[ "$unadjusted_uid" -le "$turning_point" ]]
	do
		echo -e "Unadjusted UID : $unadjusted_uid is less than or equal to turning_point : $turning_point" 		# ...and needs to be incremented
		if [[ "$adjusted_uid" -gt "$turning_point" ]]; then
			echo -e "Adjusted UID : $adjusted_uid is greater than turning_point : $turning_point"				# satisfies 1st condition of being greater than the turning_point
			uid_conflict=$( uid_exists "$adjusted_uid" )
			if [[ "$adjusted_uid" -le "$upper" ]]; then
				echo -e "Adjusted UID: $adjusted_uid is less than Upper Boundary: $upper"						# satisfies 2nd condition of being less than or equal to the upper boundary
				if [[ "$uid_conflict" != "Yes" ]]; then
				echo "$adjusted_uid";
				return
				else echo -e "Adjusted UID: $adjusted_uid is in-use -> Increment the Adjusted UID and try again"
				(( adjusted_uid++ ))
				continue
				fi
			else echo -e "Adjusted UID is greater than $upper"
			fi 
		else echo -e "Adjusted UID is less than or equal to $turning_point"			
		fi 
	done
fi

if [[ $offset -lt 0 ]]; then
adjusted_uid="$(( turning_point ))"
	while [[ "$unadjusted_uid" -gt "$turning_point" ]]
	do
		echo -e "Unadjusted UID : $unadjusted_uid is greater than the turning_point : $turning_point" 			# ...and needs to be decremented
		if [[ "$adjusted_uid" -le "$turning_point" ]]; then
			echo -e "Adjusted UID : $adjusted_uid is less than or equal to the turning_point : $turning_point"	# satisfies 1st condition of being greater than the turning_point
			uid_conflict=$( uid_exists "$adjusted_uid" )
			if [[ "$adjusted_uid" -ge "$lower" ]]; then
				echo -e "Adjusted UID: $adjusted_uid is greater than or equal to the Lower Boundary: $lower"	# satisfies 2nd condition of being less than or equal to the upper boundary
				if [[ "$uid_conflict" != "Yes" ]]; then
				echo "$adjusted_uid";
				return
				else echo -e "Adjusted UID: $adjusted_uid is in-use -> decrement the Adjusted UID and try again"
				(( adjusted_uid-- ))
				continue
				fi
			else echo -e "Adjusted UID is less than $lower"
			fi 
		else echo -e "Adjusted UID is greater than $turning_point"			
		fi 
	done
fi

}

neg_uid_offset() {
echo "poop"
}

# -------------------------------------------------- #
# MAIN
# -------------------------------------------------- #
# vars
upper=600
lower=0
turning_point="500"
offset="-100"
uid="501"



for i in {496..502}
do
	unadjusted_uid=$i
	find_adjusted_uid $unadjusted_uid
done

