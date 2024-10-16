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

wait  # Ensure filesystem sync

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

# Skip CD check and proceed to rename if track totals match
if [ "$TRACK_TOTAL" -eq "$FLAC_TOTAL" ]; then
    echo "Track totals match. Proceeding to rename files..."
else
    # RIP CD IF REQUIRED
    CD_TOTAL=$( cdparanoia -Q 2>&1 | awk '{print $1}' | grep "^[ 0-9]" | wc -l )
    if [ "$TRACK_TOTAL" -ne "$CD_TOTAL" ]; then 
        echo "Either number of tracks mismatch CD,"
        echo "or CD tracks not found."
        exit 1
    else
        echo "start ripping..."
        pushd "flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR"
        cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
        cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
        flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log
        popd 1>/dev/null
        echo
    fi
fi
# Read the track list from music.csv
# Extract track list from the CSV
TRACK_LIST=$(grep "$ARTIST" csv/music.csv | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES")

# move to target flac dir if not currently there
[ "$PWD" != "$PATH_FLAC" ] && cd "$PATH_FLAC"

count=1
for flac_file in *.flac; do
    # Extract the track name from the CSV
    track_name=$(echo "$TRACK_LIST" | sed -n "${count}p" | awk -F, '{print $8,$9}')
    
    # Make sure track_name is not empty
    if [ -z "$track_name" ]; then
        echo "Error: Track name is empty for track $count. Skipping..."
        ((count++))
        continue
    fi

    # Create the new filename
    new_filename="${track_name}.flac"

    # Rename the file if necessary
    track_number=$(echo "$new_filename" | awk '{print $1}') # Extract the track number

    if [ "$flac_file" != "$new_filename" ]; then
      echo "Renaming '$flac_file' to '$new_filename'"
      mv "$flac_file" "$new_filename"
    elif [ "$flac_file" = "$new_filename" ]; then
      echo "Track $track_number already named '$new_filename'"
fi
    ((count++))
done

# Clear metadata for each .flac file before adding new metadata
for flac_file in *.flac; do
    echo "Clearing metadata for '$flac_file'"
    metaflac --remove-all-tags "$flac_file"
done

# Define static metadata (should already be set somewhere earlier in your script)
GENRE="Rock"  # Example, adjust this based on your data
ALBUM_ARTIST="$ALBUM_ARTIST"  # Album artist is already set earlier
ALBUM="$ALBUM"
YEAR="$YEAR"
LABEL="YourLabel"
CATALOG_NUMBER="0630-18677-2"
MEDIA_SOURCE="CD"
ATTRIBUTES="$ATTRIBUTES"

# Loop through each .flac file and add metadata
count=1
for flac_file in *.flac; do
    # Extract dynamic metadata from TRACK_LIST
    track_data=$(echo "$TRACK_LIST" | sed -n "${count}p")
    DISC_NUMBER=$(echo "$track_data" | awk -F',' '{print $7}')   # Disc number
    TRACK_NUMBER=$(echo "$track_data" | awk -F',' '{print $8}')  # Track number
    TRACK_TITLE=$(echo "$track_data" | awk -F',' '{print $9}')   # Track title
    ARTIST=$(echo "$track_data" | awk -F',' '{print $3}')        # Track artist
    
    # Ensure that dynamic metadata is not empty
    if [ -z "$DISC_NUMBER" ] || [ -z "$TRACK_NUMBER" ] || [ -z "$TRACK_TITLE" ] || [ -z "$ARTIST" ]; then
        echo "Error: Missing metadata for track $count. Skipping..."
        ((count++))
        continue
    fi

    # Clear existing metadata
    echo "Clearing metadata for '$flac_file'"
    metaflac --remove-all-tags "$flac_file"
    
    # Add static metadata
    echo "Adding metadata for '$flac_file'"
    metaflac --set-tag="GENRE=$GENRE" \
             --set-tag="ALBUMARTIST=$ALBUM_ARTIST" \
             --set-tag="ALBUM=$ALBUM" \
             --set-tag="YEAR=$YEAR" \
             --set-tag="LABEL=$LABEL" \
             --set-tag="CATALOGNUMBER=$CATALOG_NUMBER" \
             --set-tag="MEDIASOURCE=$MEDIA_SOURCE" \
             --set-tag="ATTRIBUTES=$ATTRIBUTES" "$flac_file"
    
    # Add dynamic metadata for each track
    metaflac --set-tag="DISCNUMBER=$DISC_NUMBER" \
             --set-tag="TRACKNUMBER=$TRACK_NUMBER" \
             --set-tag="TITLE=$TRACK_TITLE" \
             --set-tag="ARTIST=$ARTIST" "$flac_file"
    
    echo "Metadata added for '$flac_file'"

    ((count++))
done

#
