#!/bin/bash

function help() {
  if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then 
  echo "HOW TO USE"
  echo "sh cd2flac.sh beatles"
  echo "sh cd2flac.sh 1999"
  exit 1
  fi
}

# Function to check prerequisites
function check_prerequisites() {
    if ! command -v cdparanoia &> /dev/null; then
        echo "cdparanoia is not installed:"
        echo "sudo apt install cdparanoia"
        exit 1
    fi
    if ! command -v flac &> /dev/null; then
        echo "flac is not installed:"
        echo "sudo apt install flac"
        exit 1
    fi
    if [ ! -f "csv/music.csv" ]; then
        echo "csv/music.csv file not found! :("
        exit 1
    fi
}

# Function to get matches from CSV
function get_matches() {
    HITS=$( grep -i "$1" csv/music.csv | tail -n +2 | \
    sed 's/, /__/g' | awk -F',' '{print $3" - "$5,"("$6")","["$13"]"}' | \
    sed 's/\[\]//' | sed 's/__/, /g' | sed 's/\"//g' | uniq | sort )
    if [ -z "$HITS" ]; then
        echo "no matches found for '$1' in csv/music.csv"
        exit 1
    else
        export HITS
    fi     
}

# Function to select album
function choose_album() {
    if [ $(echo "$HITS" | wc -l) -eq 1 ]; then
        echo "$HITS" | nl
        echo -n "confirm [y/n]? "
        read -r CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "invalid selection. cancelled. :("
            exit 1
        fi
        #echo "$HITS"
        MATCH="$HITS"
        export MATCH
    else
        echo "$HITS" | nl
        echo -n "select 1-$(echo "$HITS" | nl | wc -l): "
        read -r SELECTION
        if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -gt $(echo "$HITS" | wc -l) ]]; then
            echo "invalid selection. exiting. :("
            exit 1
        fi
        #echo "$(echo "$HITS" | sed -n "${SELECTION}p")"
        MATCH="$(echo "$HITS" | sed -n "${SELECTION}p")"
        export MATCH
    fi
}

function get_albumartist() {
    ALBUM_ARTIST=$(echo "$MATCH" | awk -F' - ' '{print $1}')
    export ALBUM_ARTIST
}

function get_albumyearattr() {
    ALBUM_YEAR_ATTR=$(echo "$selected_line" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//')
    export ALBUM_YEAR_ATTR
}

# Function to check CD detection
function check_cd_inserted() {
    udevadm info --query=all --name=/dev/sr0 2>/dev/null | grep -q 'ID_CDROM_MEDIA=1'
}

# Function to sanitize album and artist names (remove leading periods)
sanitize_name() {
    local name="$1"
    echo "$name" | sed 's/^[.]*//'
}


# Function to rip CD
function rip_cd() {
    local path="$1"
    echo "Start ripping..."
    pushd "$path" > /dev/null
    cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
    cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
    flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log
    popd > /dev/null
}

# Main function
main() {
    help "$1" # run help, exit if argument is blank or help flags called
    check_prerequisites # then check if csv databases exist, and cdparanoia, flac installed
    get_matches "$1" # return a list of formatted matches
    choose_album
    get_albumartist
    
    echo "$MATCH"
    echo "$ALBUM_ARTIST"
#    echo "$HITS"
#    check_cd_inserted # check if cd is inserted into cd player 
#    if [[ $? -eq 0 ]]; then
#        # if CD inserted, 
#        # 
#        echo "CD is inserted. Starting to rip..."
#    fi
#    
#    matches=$(get_matches "$argument")
#    selected_line=$(select_album "$matches")
#
#    # Parse values
#    ALBUM_ARTIST=$(echo "$selected_line" | awk -F' - ' '{print $1}')
#    ALBUM_YEAR_ATTR=$(echo "$selected_line" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//')
#
#    # Sanitize album artist and album name to remove leading periods
#    SANITIZED_ALBUM_ARTIST=$(sanitize_name "$ALBUM_ARTIST")
#    SANITIZED_ALBUM_YEAR_ATTR=$(sanitize_name "$ALBUM_YEAR_ATTR")
#
#    # Always create sanitized directories to avoid hidden folders
#    PATH_FLAC="flac/$SANITIZED_ALBUM_ARTIST/$SANITIZED_ALBUM_YEAR_ATTR"
#    mkdir -p "$PATH_FLAC"
#
#    if check_cd_inserted; then
#        echo "CD detected, checking track totals..."
#        TRACK_TOTAL=$(grep "$ARTIST" csv/music.csv | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | wc -l)
#        CD_TOTAL=$(cdparanoia -Q 2>&1 | awk '{print $1}' | grep "^[ 0-9]" | wc -l)
#
#        if [ "$TRACK_TOTAL" -ne "$CD_TOTAL" ]; then
#            echo "Either number of tracks mismatch CD,"
#            echo "or CD tracks not found."
#            exit 1
#        else
#            rip_cd "$PATH_FLAC"
#        fi
#    else
#        echo "No CD detected, skipping ripping process and proceeding to metadata."
#    fi
#
#    # Move to the sanitized directory if it's not the current working directory
#    if [ "$PWD" != "$PATH_FLAC" ]; then
#        cd "$PATH_FLAC" || { echo "Error: Directory $PATH_FLAC not found."; exit 1; }
#    fi
#
#    # Rename files if any are found
#    count=1
#    for flac_file in *.flac; do
#        # Extract track name from CSV
#        track_name=$(echo "$TRACK_LIST" | sed -n "${count}p" | awk -F, '{print $8,$9}')
#        
#        if [ -z "$track_name" ]; then
#            echo "Error: Track name is empty for track $count. Skipping..."
#            ((count++))
#            continue
#        fi
#
#        # Create the new filename
#        new_filename="${track_name}.flac"
#
#        # Rename the file
#        if [ "$flac_file" != "$new_filename" ]; then
#            echo "Renaming '$flac_file' to '$new_filename'"
#            mv "$flac_file" "$new_filename"
#        else
#            echo "Track $count already named correctly as '$new_filename'"
#        fi
#        ((count++))
#    done
}

# Run the main function
main "$1"

