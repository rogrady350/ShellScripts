#!/bin/bash
# Robert O'Grady   S1365114

# names2userids: Script to create unique userids from a list of user names
# CS 370

# function prints usage and exits
function usage {
   echo "Usage: $0 [nameslist file]"
   echo "       where nameslist contains names in \"Last, First\" format"
   exit 1
}

# Check for exactly 1 command line arg. If not print usage and exit
if [ $# -ne 1 ]; then
   usage
fi

#names list file from command line arg
inputfile=$1

# Check if input file exits. If not print error message and exit.
if [ ! -f "$inputfile" ]; then
   echo "Input file not found."
   exit 1
fi

#zenity
	# Get the total number of lines in the input file
	num_names=$(wc -l < "$inputfile")
	
	# Remove the named pipe if it exists
    if [ -p /tmp/progress_pipe ]; then
        rm /tmp/progress_pipe
    fi

	# Create a named pipe to send progress updates to zenity
	mkfifo /tmp/progress_pipe    

	# Start zenity progress bar in the background
	(zenity --progress --title="Processing" --text="Overall Progress" --percentage=0 --auto-close --width=400 --height=100 2>/dev/null < /tmp/progress_pipe) &
	exec 3> /tmp/progress_pipe   # Open the named pipe for writing

	# Function to update the progress bar
	function show_progress {
	  local progress=$1      # set argument to be the progress value displayed
	  echo "$progress" >&3   # redirect this value to named pipe
	}

# 0. Remove any temporary files from previous runs of the script.
#    This is essential during script testing.
echo "Removing previous temp files"
rm -f firstn lasname ids_1st ids_2nd duplids inputfile_tmp ids_final

show_progress 0

# 1. Create firstn from $inputfile (first letter of first name)
echo "Gathering first initials"
cut -d "," -f 2 "$inputfile" |   		# get first name from 2nd arg on each line
cut -c 2		  		     |   	    # get first char of first name (second char after delimeter, after leading space)
tr '[:upper:]' '[:lower:]' > firstn	    # write lowercase first char

show_progress 5

# 2. Create lastname from $inputfile with all special characters removed
echo "Gathering up to 7 characters of last names"
cut -d "," -f 1 "$inputfile" |   		# get last name from 1st arg on each line
sed 's/[^a-zA-Z]//g'	     |   		# remove all special characters
cut -c 1-7                   |   		# get up to 7 chars of last name
tr '[:upper:]' '[:lower:]' > lastname   # write lowercase last name

show_progress 10

# 3. Create first draft userids file from firstn and lastname > ids_1st'.
#    It contains userids in this format:
#    [1st letter of first name][1st seven letters of last name]
echo "Joining firstn and lastname to create initial UserID's"
paste -d "" firstn lastname > ids_1st # join firstn and lastname

show_progress 15

# We want to keep the ids_1st file in the same order as $inputfile
# since we want to be able to paste the ids file and $inputfile
# together at some point, like this (after duplicate ids have been
# dealt with):
#
#     Abraham, Jesse :jabraha1
#     Abrahamsen, Theresa :tabraham
#     Abrahamson, Jonathan :jabraha2
#     Abrams, Jenelle :jabrams1
#     Abrams, Dana :dabrams
#     Abrams, Jessica :jabrams2

# 4. Create list of the duplicated ids in ids_1st > duplids'.
#    We'll use duplids as a lookup table.
echo "Finding duplicate ID's"
sort ids_1st | uniq -d > duplids

show_progress 20

# 5. Append userids from ids_1st to ids_2nd.
#    If a userid is duplicated, attach appropriate numbers to them
#    and append to ids.2nd.

# need a way to keep track of the length of the userid as numbers are appended
# as numbers increase to double digits, or potentially larger (possible with extremely large name lists)
# to stay within the 8 character length requirment, a way of keeping track of userid length is needed
# initialize an array to keep track of this
echo "Appending duplicates to keep all ID's unique"

declare -A userid_count   # array to store userid lengths
declare -A all_ids        # array to keep track of generated ids as appended

current_lines=0   # number of lines read from file used for progress bar calculation

while read -r id; do
	original_id="$id"  # Store the original ID
	
    if grep -wq "$id" duplids; then
        # If the userid is duplicated, initialize or increment the counter
        if [[ -z ${userid_count["$id"]} ]]; then   # check if this is the first instance of the userid
            userid_count["$id"]=1                  # if so set initially value to 1
        else
            userid_count["$id"]=$((userid_count["$id"] + 1)) # increment if not the first instance
        fi
        
        # Append the number to the userid, ensuring total length is no more than 8 chars
        num=${userid_count["$id"]}   # number to be appended
        
        # Calculate total length to see if characters need to be removed
        tot_length=$((${#id} + ${#num}))
        
        # only remove characters if adding number to end will make the total length greater than 8
        if [ "$tot_length" -gt 8 ]; then        # if greater than remove
			remaining_length=$((8 - ${#num}))   # calculate how many chars to remove
			temp_id="${id:0:remaining_length}${num}"
		else                                    # otherwise just append numbers to end
			temp_id="${id}${num}"
		fi
		
		# Ensure the new ID is unique. Check for situations when shortening causes an id to become a duplicate
        while [[ -n ${all_ids["$temp_id"]} ]]; do								# runs as long as temp_id is in all_ids
            userid_count["$original_id"]=$((userid_count["$original_id"] + 1))  # increment counter for original id to make unique
            num=${userid_count["$original_id"]}									# assign new incremented value to num
            tot_length=$((${#original_id} + ${#num}))							# recalculate tot_length
            
            # adjust if length exceeds 8 characters
            if [ "$tot_length" -gt 8 ]; then
                remaining_length=$((8 - ${#num}))
                temp_id="${original_id:0:remaining_length}${num}"
            else
                temp_id="${original_id}${num}"
            fi
            
        done                        # exit when id is made unique by incrementing appended number
        echo "$temp_id" >> ids_2nd  # append id to ids_2nd
        all_ids["$temp_id"]=1		# mark newly created id as used by adding it to the all_ids array
			
    else
        # If the userid is unique, append it straightaway to ids_2nd
        echo "$id" >> ids_2nd
    fi
    
    # Update progress
    current_lines=$((current_lines + 1))				# increment the lines read
    step_progress=$((current_lines * 100 / num_names))	# progress of names processed
    show_progress $((20 + step_progress * 70 / 100))	# increase progress bar from 20 to 90
    
done < ids_1st

show_progress 90

# 6. Double check ids.2nd for any userid duplications.
#    The same uniq option used to create duplids (step 4) should work.
echo "Confirming all UserID's are unique"
sort ids_2nd | uniq -d > duplids_check
duplids_check_count=$(wc -l < duplids_check) # duplids_check should be empty (=0)

if [ "$duplids_check_count" -eq 0 ]; then
	echo "All UserID's are unique"
else
	echo "List contains duplicates"
fi

show_progress 95

# 7. Paste ids_2nd to $inputfile > ids_final
echo "Creating finalized UserID list"
awk '{gsub(/[[:space:]]+$/, ""); print $0 " :"}' "$inputfile" > inputfile_tmp  # original name list with : added
																			   # output formatted to remove trailing spaces from input file
paste -d "" inputfile_tmp ids_2nd > ids_final                                  # add ids to this list

show_progress 100

# 8. Completion message
echo "Successfully generated UserID list"

# Close the progress bar and remoeve named pipe
exec 3>&-
rm -f /tmp/progress_pipe
