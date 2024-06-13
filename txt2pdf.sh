!/bin/bash
# Robert O'Grady   S1365114
# txt2pdf: converts text file to pdf

# function prints usage and exits
function usage {
   echo "Usage: $(basename "$0") [empty(-1) for 1 page or -2 for 2 pages] [fileName.txt]"
   exit 1
}

# Help function. Text displayed when -h option used
# Shows program synopsis, explanation of sript options and example usages.
function help {
   echo "Synopsis:"
   echo "  txt2pdf.sh [-2] <fileName.txt>"
   echo
   echo "Description:"
   echo "  This script converts a text file to a PDF file."
   echo
   echo "Options:"
   echo "  -2	 Convert with 2 pages per sheet."
   echo "  -h	 Display this help message."
   echo
   echo "Examples:"
   echo "  txt2pdf.sh fileName.txt	 Convert with 1 page per sheet."
   echo "  txt2pdf.sh -2 fileName.txt	 Convert with 2 pages per sheet."
   exit 0
}

# check command line args
# check for 1 or 2 args. If not 1 or 2 args, print usage and exit.
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
   usage
fi

# check for -2 or -h  option
# if -2 entered, set option varialbe = 2 for use in conversion pipeline
# set input_file = to second command line arg
if [ "$1" = "-2" ]; then
   option="2"
   input_file="$2"
   # check if user provided a file name. If not print usage
   if [ -z "$input_file" ]; then
      usage
   fi

# if -h entered, display help synopsis and exit
elif [ "$1" = "-h" ]; then
   help

# set option variable = 1 if -2 option is not used in command line
# set input_file = to the command line arg
else
   option="1"
   input_file="$1"
fi

# Check if input file exits. If not print error message and exit.
if [ ! -f "$input_file" ]; then
   echo "Input file not found."
   exit 1
fi

# Check if input file is a text file
if [[ "$input_file" != *.txt ]]; then
   echo "Must provovide a text file only."
   exit 1
fi

# Define the pdf output file name
output_file="${input_file}.pdf"

#check if converted file exits and confirm overwrite
if [ -f "$output_file" ]; then
   echo "That file already exists. Overwrite? (y/n)"
   read -r answer
   if [ $answer = "n" ] || [ $answer = "N" ]; then
      exit 1
   fi
fi

#convert given text file to PostScript
enscript $"$input_file" -o - | psnup -"$option" | ps2pdf - "$output_file"

#Inform succesful conversion
echo "Coversion complete: Successfuly created ${output_file}"
