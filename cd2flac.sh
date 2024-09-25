#!/bin/bash

# Check if argument is provided
if [ -z "$1" ]; then
  echo "Usage: sh cd2flac.sh <CD_IDENTIFIER>"
  echo "Example: sh cd2flac.sh '0630-18677-2'"
  exit 1
fi

# Check for necessary commands
if ! command -v cdparanoia &> /dev/null; then echo "cdparanoia is not installed."; exit 1; fi
if ! command -v flac &> /dev/null; then echo "flac is not installed."; exit 1; fi

# Check if music.csv exists
if [ ! -f "csv/music.csv" ]; then echo "csv/music.csv file not found!"; exit 1; fi

argument=$( grep -i "$1" csv/music.csv )

# Search for argument in csv, if no matches, exit
if [ -z "$argument" ]; then 
    echo "no matches found for '$1' in csv/music.csv"
    exit 1
fi

# SELECT ALBUM
matches=$( cat csv/music.csv | tail -n +2 | grep "$argument" | \
sed 's/, /__/g' | awk -F',' '{print $3" - "$5,"("$6")","["$13"]"}' | sed 's/\[\]//' | \
sed 's/__/, /g' | sed 's/\"//g' | uniq | sort )

if [ -z "$matches" ]; then
    echo "invalid selection. exiting."
    exit 1
fi

if [ $( echo "$matches" | wc -l ) -eq 1 ]; then
    selected_line="$matches"
    echo "$selected_line" | nl
    echo -n "confirm [y/n]? "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "cancelled"
        exit 1
    fi
elif [ $( echo "$matches" | wc -l ) -gt 1 ]; then
    echo "$matches" | nl
    echo -n "select 1-$( echo "$matches" | nl | wc -l ): "
    read -r selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $( echo "$matches" | wc -l ) ]; then
        echo "Invalid selection. Exiting."
        exit 1
    fi
    selected_line=$( echo "$matches" | sed -n "${selection}p" )
    echo "you selected:"
    echo "$selected_line"
else
    echo "no matches found."
    exit 1
fi

# Parse CSV for values
ALBUM_ARTIST="$( echo "$selected_line" | awk -F' - ' '{print $1}' )"
ALBUM_YEAR_ATTR="$( echo "$selected_line" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//' )"

# Create directories if not present
[ ! -d "flac" ] && mkdir "flac"
[ ! -d "flac/$ALBUM_ARTIST" ] && mkdir "flac/$ALBUM_ARTIST"
[ ! -d "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR" ] && mkdir "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR"

sleep 1  # Ensure filesystem sync

# Clean path and ensure the directory exists
PATH_FLAC="flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR"

# Get artist, album, year, and attributes from the selected line
ARTIST=$( echo "$selected_line" | sed 's/\ \-\ .*//' )
ALBUM=$( echo "$selected_line" | sed 's/.* \-\ //' | rev | sed 's/.*(//' | rev | sed 's/[[:space:]]\+$//' )
YEAR=$( echo "$selected_line" | sed 's/.* \-\ //' | rev | sed 's/(.*//' | rev | sed 's/).*//' )
ATTRIBUTES=$( echo "$selected_line" | rev | sed 's/).*//' | rev | sed 's/^ \[//' | sed 's/\]//' )

# Get track and FLAC totals
TRACK_TOTAL=$( cat "csv/music.csv" | grep "$ARTIST" | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | wc -l )
FLAC_TOTAL=$( ls "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR" | grep ".flac" | wc -l )

# RIP CD IF REQUIRED
if [ "$TRACK_TOTAL" -ne "$FLAC_TOTAL" ]; then
    CD_TOTAL=$( cdparanoia -Q 2>&1 | awk '{print $1}' | grep "^[ 0-9]" | wc -l )
    if [ "$TRACK_TOTAL" -ne "$CD_TOTAL" ]; then 
        echo "track mismatch"
        exit 1
    else
        echo "start ripping..."
        cd "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR"
        cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
        cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
        flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log
    fi
fi

TRACK_LIST=$(cat "csv/music.csv" | grep "$ARTIST" | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES")
echo "Renaming files..."
[ "$PWD" != "$PATH_FLAC" ] && cd "$PATH_FLAC"
count=1
for flac_file in *.flac; do
    track_name=$(echo "$TRACK_LIST" | sed -n "${count}p" | sed 's/, /__/g' | awk -F, '{print $8,$9}' | sed 's/__/, /' | sed 's/\"//g' )
    new_filename="${track_name}.flac"

    if [ "$flac_file" != "$new_filename" ]; then
        echo "renaming '$flac_file' to '$new_filename'"
        mv "$flac_file" "$new_filename"
    else
        echo "'$flac_file' is already correctly named."
    fi
    ((count++))
done

#