#!/bin/bash

FindAllFilesOfType() {
	local fileType="$1"
	declare -n fileArray="$1""Files"
	
	while IFS= read -r -d '' file; do
    # Check if the file is a Log file
		if [[ "$file" == *."$fileType" ]]; then
			# Add the file to the array
			fileArray+=("$file")
		fi
		#Add -maxdepth 1 to exclude subdirectories. 
	done < <(find . -maxdepth 1 -type f -name "D5_*.$fileType" -print0)
	declare +n fileArray
}

CheckForExistingConversions() {
    for log in "${logFiles[@]}"; do
        local isUnique=true
        for csv in "${csvFiles[@]}"; do
            if [[ "${log%.*}" == "${csv%.*}" ]]; then
                isUnique=false
                break
            fi
        done
        if $isUnique; then
            logsToConvert+=("$log")
        fi
    done
}

ConvertLogFiles() {
	local -n finalFiles=$1
	local header=$2
	
	for logFile in "${finalFiles[@]}"; do
		# Skip the first 15-byte row and process the remaining data as unsigned bytes
		hexdump -s 15 -v -e '15/1 "%u," "\n"' "$logFile" | \
		sed 's/,$//' | \
		# Add Time column, add column and convert O2 ADC to AFR
		awk -v header="Time,AFR,$header" -v a="0" -v b="255" -v c="7.35" -v d="22.39" '
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
		}' > "${logFile%.*}.csv"
		
		echo "${logFile%.*} .log -> .csv"
	done
}

# File types to find
declare -a fileTypes=("csv" "log")
# Header for new CSV files
newHeader="Output,col02,col03,MAF,TPS,col06,col07,O2,col09,col10,col11,ECT,O2SM,col14,col15"

# Find files of 'fileTypes', declare an array and store them.
for fileType in "${fileTypes[@]}"; do
	declare -a "fileType""Files"
	FindAllFilesOfType "$fileType"
	done

# Declare an array to store files to be converted
declare -a logsToConvert
# Prevent reprocessing converted files
CheckForExistingConversions

ConvertLogFiles logsToConvert $newHeader

echo "Converted ${#logsToConvert[@]} logs."












