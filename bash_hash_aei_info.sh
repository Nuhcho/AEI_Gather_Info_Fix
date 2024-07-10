#!/bin/sh



#Checks if the file exists
fileExists() {
    [ -f "$1" ]
}


#Checks permissions
hasReadWritePermissions() {
    [ -r "$1" ] && [ -w "$1" ]
}


#Locations for the files
File_to_run="/sbin/aei_gather_info.sh"
File_to_check="/tmp/aei_gather_info/gather_info.log"
TGZ_File="/tmp/aei_gather_info.tgz"

# Runs the script to ensure that the script exists and the tgz file is created
if fileExists "$File_to_run"; then
    echo "Running script: $File_to_run"
    sh "$File_to_run"
else
    echo "Script not found: $File_to_run"
    exit 1
fi

# Extract the TGZ file
echo "Extracting $TGZ_File"
tar -xzf "$TGZ_File" -C /tmp

# Check if the file exists after extraction
if fileExists "$File_to_check"; then
    echo "File extracted successfully: $File_to_check"
else
    echo "File does not exist after extraction: $File_to_check"
    exit 1
fi

# List of words to check, separated by spaces.
Words_to_check="WPAKey WPSAPPIN AeiAdminPwd .key wpa_passphrase"

# Check if the file exists and has the correct permissions
if fileExists "$File_to_check"; then
    echo "File exists: $File_to_check"
else   
    echo "File does not exist: $File_to_check"
    exit 1
fi


#Checks permissions
if ! hasReadWritePermissions "$File_to_check"; then
    echo "File does not have permissions to read/write: $File_to_check"
    exit 1
fi

#Creates a temporary file to store hashed data and eventually replace with the old log file
tempFile="/tmp/temp.log"

# Processes the file and splits each line that contains one of the keys in two and hashes the second half. This is then stored to the temp file along with the rest of the 
#non-key lines and is swapped with the original log file at the end.
while IFS= read -r line; do
    lineModified=false
    for key in $Words_to_check; do
        key=$(echo "$key" | tr -d "'")
        if echo "$line" | grep -q "$key"; then
            delimiter="="
            if echo "$line" | grep -q "$key$delimiter"; then
                firstHalf=$(echo "$line" | cut -d"$delimiter" -f1)
                secondHalf=$(echo "$line" | cut -d"$delimiter" -f2- | awk '{print $1}')
                shaHash=$(echo -n "$secondHalf" | sha256sum | awk '{print $1}')
                rest=$(echo "$line" | cut -d"$delimiter" -f2- | awk '{$1=""; print $0}')
                line="$firstHalf$delimiter$shaHash $rest" 
                lineModified=true
                break
            fi
        fi
    done
    echo "$line" >> "$tempFile"
done < "$File_to_check"

#Replaces the temp log file with the old log file
mv "$tempFile" "$File_to_check"
