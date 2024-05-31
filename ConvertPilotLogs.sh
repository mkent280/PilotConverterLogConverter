#!/bin/bash
usage() {
    echo "Usage: $Directory"
    echo "Copies Pilot converter .log files into csv files."
	echo "Checks for existing .csv files of same name and skips them."
	echo "starting with No options will check for cfg file containing a directory"
	echo "if no cfg file is found, the current directory will be used"
    echo "Options:"
	echo "-o	Overwrite all conflicting .csv files, do not check for existing files"
    echo "-c	Specify a single log file."
    echo "-h	Display this help message."
    exit 1
}

# Finds files of specified file types $1 fileArray $2 directory
FindAllFilesOfType() { 
	local -n fileArray="$1" # declare temporary pointer
	local dir=$2	
	local fileType
	if [[ $1 == "logFiles" ]]; then
		fileType="log"
	elif [[ $1 == "csvFiles" ]]; then
		fileType="csv"
	else
		exit 1
	fi
	
	while IFS= read -r -d '' file; do
		if [[ "$file" == *."$fileType" ]]; then
			# Add the file to the array
			fileArray+=("$file")
		fi
		# -maxdepth 1 to exclude subdirectories. 
	done < <(find "$dir" -maxdepth 1 -type f -name "D*.$fileType" -print0)
}

# Check single .log file header, returns 0=match, 1=false
CheckIfLogIsPilotLog(){
	local log=$1
	local compareHeader="00 00 50 69 4C 6F 54 00 01 00 01 00 44 E4 19" # Default Pilot header
	if [[ "$(hexdump -n 15 -v -e '15/1 "%02X " "\n"' "$log")" == "$compareHeader" ]]; then
			return 0 
		else
			echo "$(basename $log) file header does not match a Pilot log file."
			return 1 # if header does not match, return false
	fi
}

# Check a single log if it already exists as CSV
CheckForExistingCsvOfLogName() {
	local log=$1
		for csv in "${csvFiles[@]}"; do
            if [[ "${log%.*}" == "${csv%.*}" ]]; then
				echo "A csv with the file name $(basename ${log%.*}) already exists, skipping."
				return 1 # if file is present, return false 
				break
            fi
        done
		return 0
}

# pass in $1 logFiles and $2 functionThatReturnsBool, false removes the $log from the list
RunFunctionOnLogFiles() { 
	local -n logsIn=$1
	local -a logsOut
	local function=$2
	
    for log in "${logsIn[@]}"; do
		if $function $log; then
			logsOut+=("$log")
		fi
    done
	# Copy new array back out
	logsIn=("${logsOut[@]}")
}

# $1 OPTARG
ConvertSingleLog() {
	local log="$(dirname "$1")/$(basename "$1")"
	local continue=0

	FindAllFilesOfType csvFiles $(dirname "$1")
	if [[ $overWrite == false ]]; then
		CheckForExistingCsvOfLogName $log
		continue=$?
	fi
	
	if CheckIfLogIsPilotLog "$log" && [ $continue == 0 ] ; then
		DumpHexAndCreateCsv $log $newHeader
	else
		exit 0
	fi
}

# $1 stringlogFile $2 stringHeader
DumpHexAndCreateCsv() {
		local log=$1
		# Skip the first 15-byte row and process the remaining data as unsigned bytes
		hexdump -s 15 -v -e '15/1 "%u," "\n"' "$log" | \
		sed 's/,$//' | \
		# Add Time column, add column and convert O2 ADC to AFR
		awk -v header="Time,AFR,$newHeader" -v a="0" -v b="255" -v c="7.35" -v d="22.39" '
			BEGIN {
				FS=OFS=","
			} 
			NR == 1 {
				print header
			} 
			NR > 1 {
				print NR/100, 
				c + (d - c) / (b - a) * ($8 - a), 
				$0 
		}' > "${log%.*}.csv"
		echo "${log%.*} .log -> .csv"
}

# looks for valid config file containing /path/to/log/files
CheckForConfigFile() {
	local dir
	
	if [[ -a $configFile ]]; then
		dir=$(cat $configFile)
	fi
	
	if [[ -d $dir ]]; then
		logDir=$dir
		return 0
	else
		return 1
	fi
}

################### Variables are setup here ###################
configFile="ConvertPilotLogs.cfg"
logDir="." # default current directory
overWrite=false
declare -a fileTypes=("csv" "log")
declare -a logFiles
declare -a csvFiles
# Header for output CSV files, this is incomplete as I do not have all the inputs hooked up.
newHeader="Output,col02,col03,MAF,TPS,col06,col07,O2,col09,col10,col11,ECT,O2SM,col14,col15"

################### Main script execution ###################
# Parse command-line options
while getopts ":c:oh" opt; do
    case $opt in
        c)	#If Single file is selected, skip all folder operations
			ConvertSingleLog $OPTARG
			exit 0
			;;
		o)	overWrite=true
			;;
        h)	usage
			;;
        \?)	echo "Invalid option: -$OPTARG" >&2
			usage
            ;;
    esac
done
shift "$(($OPTIND -1))"

# if param blank, check for config, if config blank use current directory.
if [[ -d $1 ]]; then
	logDir=$1
	echo "Using input directory"
elif CheckForConfigFile; then
	echo "Using dir from cfg $logDir" 
else	
	echo "Using current directory"
fi

# Find log Files
FindAllFilesOfType logFiles $logDir
if [[ "${#logFiles[@]}" -eq 0 ]]; then
	echo "No .log files were found in the directory $logDir"
	exit 1
fi
# Find csv Files
FindAllFilesOfType csvFiles $logDir

# Prevent overWrite of existing csv files
if [[ $overWrite == false ]]; then
	RunFunctionOnLogFiles logFiles CheckForExistingCsvOfLogName
fi

# Remove from list if 15-byte header mismatch
RunFunctionOnLogFiles logFiles CheckIfLogIsPilotLog

# Convert the remaining list of logs
RunFunctionOnLogFiles logFiles DumpHexAndCreateCsv

echo "Converted ${#logFiles[@]} logs."
# I know its not very pretty, but its functional. 








