#!/bin/bash

# 
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
if [ ! -f "csv/music.csv" ]; then echo "csv/music.csv file not found!"; exit 1; fi

argument=$( grep -i "$1" csv/music.csv )

# Search for argument in csv, if no matches, exit
if [ -z "$argument" ]; then 
echo "no matches found for '$1' in csv/music.csv"; exit 1; fi

# 
if [ ! -z "$argument" ]; then
matches=$( cat csv/music.csv | tail -n +2 | grep "$argument" | \
sed 's/, /__/g' | awk -F',' '{print $3" - "$5,"("$6")","["$13"]"}' | sed 's/\[\]//' | \
sed 's/__/, /g' | sed 's/\"//g' | uniq )

  if [ -z "$matches" ]; then
    echo "invalid selection. exiting."; exit 1; fi

  if [ $( echo "$matches" | wc -l ) -eq 1 ]; then
    selected_line="$matches"
    echo "$selected_line"; exit 0; fi

  if [ $( echo "$matches" | wc -l ) -gt 1 ]; then
    echo "$matches" | nl
    echo -n "select 1-$( echo "$matches" | nl | wc -l ): "; read -r selection
    
    # Minimal input validation check
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $( echo "$matches" | wc -l ) ]; then
    echo "Invalid selection. Exiting."; exit 1; fi
    
    selected_line=$( echo "$matches" | sed -n "${selection}p" )
    echo "you selected:"
    echo "$selected_line"; fi

fi

# 
ALBUM_ARTIST="$( echo "$selected_line" | awk -F' - ' '{print $1}' )"
ALBUM_YEAR_ATTR="$( echo "$selected_line" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//' )"

#
# create flac directory if not created
if [ ! -d "flac" ]; then mkdir "flac"; fi

# create album artist directory if not created
if [ ! -d "flac/$ALBUM_ARTIST" ]; then mkdir "flac/$ALBUM_ARTIST"; fi

# create album artist directory if not created
if [ ! -d "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR" ]; then mkdir "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR"; fi

# if directory is empty, proceed to convert into directory
#if [ -z $(ls -A "flac/$album_artist/$album_year_attr") ]; then 
#  #
#  cd "flac/$album_artist/$album_year_attr"

#  # rip cd to aiff and convert to flac
#  cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
#  cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
#  flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log
#fi

# if target directory not empty, get values from selected_line and parse csv for track totat  
if [ ! -z $(ls -A "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR") ]; then echo "not empty"; 
else echo "empty"; fi
  ARTIST=$( echo "$selected_line" | sed 's/\ \-\ .*//' ); echo "$ARTIST"
  ALBUM=$( echo "$selected_line" | sed 's/.* \-\ //' | rev | sed 's/.*(//' | rev | sed 's/[[:space:]]\+$//'); echo "$ALBUM"
  YEAR=$( echo "$selected_line" | sed 's/.* \-\ //' | rev | sed 's/(.*//' | rev | sed 's/).*//' ); echo "$YEAR"
  ATTRIBUTES=$( echo "$selected_line" | rev | sed 's/).*//' | rev | sed 's/^ \[//' | sed 's/\]//'); echo "$ATTRIBUTES"
  TRACK_TOTAL=$( cat "csv/music.csv" | grep "$ARTIST" | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" )
#fi

echo "$TRACK_TOTAL"
 
# If multiple matches are found, display the list and ask the user to select
# if [ "$( echo $ | wc -l ) -gt 1 ]; then
#  echo "Multiple matches found for '$1':"
#  matches=$( cat csv/music.csv | grep "$1" | sed 's/, /__/g' | awk -F',' '{print $3" - "$5,"("$6")","["$13"]"}' | sed 's/\[\]//' | sed 's/__/, /g' | sed 's/\"//g' | uniq )
#  echo "$matches" | nl
#  echo "Please select the number corresponding to the correct album:"
#  read -r selection

  # Validate the user's input
#  selected_line=$( echo "$matches" | sed -n "${selection}p" )
#  if [ -z "$selected_line" ]; then
#    echo "Invalid selection. Exiting."
#    exit 1
#  fi
#fi
  # Extract the CD identifier from the selected line (assuming it's in the first column)
#  cd_identifier=$(echo "$selected_line" | cut -d',' -f1)
#else
#  # Only one match, so we use it directly
#  cd_identifier=$(echo "$matches" | cut -d',' -f1)
#fi

# Rip CD to AIFF and convert to FLAC
#cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
#cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
#flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log

#echo "START RIPPING"
#echo "done"

# Call the Python script with the selected CD identifier as an argument
#python3 meta2flac.py "$cd_identifier"


