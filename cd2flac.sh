#!/bin/bash

# Check if argument is provided, if not, show help message
if [ -z "$1" ]; then
  echo "Usage: sh cd2flac.sh <CD_IDENTIFIER>"
  echo "Example: sh cd2flac.sh '0630-18677-2'"
  exit 1
fi

# Check for cdparanoia and flac
if ! command -v cdparanoia &> /dev/null; then echo "cdparanoia is not installed."; exit 1; fi
if ! command -v flac &> /dev/null; then echo "flac is not installed."; exit 1; fi

# Check if music.csv exists
if [ ! -f "csv/music.csv" ]; then
  echo "csv/music.csv file not found!"
  exit 1
fi

# Search for the CD identifier in csv/music.csv
matches=$(grep -i "$1" csv/music.csv)

# If no matches are found, exit with an error message
if [ -z "$matches" ]; then
  echo "No matches found for '$1' in csv/music.csv."
  exit 1
fi

# If multiple matches are found, display the list and ask the user to select
if [ $(echo "$matches" | wc -l) -gt 1 ]; then
  echo "Multiple matches found for '$1':"
  echo "$matches" | nl
  echo "Please select the number corresponding to the correct album:"
  read -r selection

  # Validate the user's input
  selected_line=$(echo "$matches" | sed -n "${selection}p")
  if [ -z "$selected_line" ]; then
    echo "Invalid selection. Exiting."
    exit 1
  fi

  # Extract the CD identifier from the selected line (assuming it's in the first column)
  cd_identifier=$(echo "$selected_line" | cut -d',' -f1)
else
  # Only one match, so we use it directly
  cd_identifier=$(echo "$matches" | cut -d',' -f1)
fi

# Rip CD to AIFF and convert to FLAC
cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log

# Call the Python script with the selected CD identifier as an argument
python3 meta2flac.py "$cd_identifier"


