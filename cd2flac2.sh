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
check_prerequisites() {
    if ! command -v cdparanoia &> /dev/null; then
        echo "cdparanoia is not installed."
        exit 1
    fi
    if ! command -v flac &> /dev/null; then
        echo "flac is not installed."
        exit 1
    fi
    if [ ! -f "csv/music.csv" ]; then
        echo "csv/music.csv file not found!"
        exit 1
    fi
}

function confirm_match() {
    argument=$(grep -i "$1" csv/music.csv)
    if [ -z "$argument" ]; then
        echo "no matches found for '$1' in csv/music.csv"
        exit 1
    fi
}

# Function to get matches from CSV
function get_matches() {
    grep -i "$1" csv/music.csv | tail -n +2 | \
    sed 's/, /__/g' | awk -F',' '{print $3" - "$5,"("$6")","["$13"]"}' | \
    sed 's/\[\]//' | sed 's/__/, /g' | sed 's/\"//g' | uniq | sort
}


# Function to check CD detection
function check_cd_inserted() {
    udevadm info --query=all --name=/dev/sr0 | grep -q 'ID_CDROM_MEDIA=1'
}

# Function to sanitize album and artist names (remove leading periods)
sanitize_name() {
    local name="$1"
    echo "$name" | sed 's/^[.]*//'
}


# Function to get matches from CSV
get_matches() {
    grep -i "$1" csv/music.csv | tail -n +2 | \
    sed 's/, /__/g' | awk -F',' '{print $3" - "$5,"("$6")","["$13"]"}' | \
    sed 's/\[\]//' | sed 's/__/, /g' | sed 's/\"//g' | uniq | sort
}

# Function to select album
select_album() {
    matches="$1"
    if [ -z "$matches" ]; then
        echo "invalid selection. exiting."
        exit 1
    elif [ $(echo "$matches" | wc -l) -eq 1 ]; then
        echo "$matches" | nl
        echo -n "confirm [y/n]? "
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "cancelled"
            exit 1
        fi
        echo "$matches"
    else
        echo "$matches" | nl
        echo -n "select 1-$(echo "$matches" | nl | wc -l): "
        read -r selection
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $(echo "$matches" | wc -l) ]]; then
            echo "Invalid selection. Exiting."
            exit 1
        fi
        echo "$(echo "$matches" | sed -n "${selection}p")"
    fi
}

# Function to rip CD
rip_cd() {
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
    # first run help if argument is blank or help flag called
    help
    # then check if csv databases exist, and cdparanoia, flac installed
    check_prerequisites
    # verify argument is found in csv database
    confirm_match
    # check if cd is inserted into cd player


    
    check_cd_inserted
    if [[ $? -eq 0 ]]; then
        # if CD inserted, 
        # 
        echo "CD is inserted. Starting to rip..."
    fi
    

    matches=$(get_matches "$argument")
    selected_line=$(select_album "$matches")

    # Parse values
    ALBUM_ARTIST=$(echo "$selected_line" | awk -F' - ' '{print $1}')
    ALBUM_YEAR_ATTR=$(echo "$selected_line" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//')

    # Sanitize album artist and album name to remove leading periods
    SANITIZED_ALBUM_ARTIST=$(sanitize_name "$ALBUM_ARTIST")
    SANITIZED_ALBUM_YEAR_ATTR=$(sanitize_name "$ALBUM_YEAR_ATTR")

    # Always create sanitized directories to avoid hidden folders
    PATH_FLAC="flac/$SANITIZED_ALBUM_ARTIST/$SANITIZED_ALBUM_YEAR_ATTR"
    mkdir -p "$PATH_FLAC"

    if check_cd_inserted; then
        echo "CD detected, checking track totals..."
        TRACK_TOTAL=$(grep "$ARTIST" csv/music.csv | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | wc -l)
        CD_TOTAL=$(cdparanoia -Q 2>&1 | awk '{print $1}' | grep "^[ 0-9]" | wc -l)

        if [ "$TRACK_TOTAL" -ne "$CD_TOTAL" ]; then
            echo "Either number of tracks mismatch CD,"
            echo "or CD tracks not found."
            exit 1
        else
            rip_cd "$PATH_FLAC"
        fi
    else
        echo "No CD detected, skipping ripping process and proceeding to metadata."
    fi

    # Move to the sanitized directory if it's not the current working directory
    if [ "$PWD" != "$PATH_FLAC" ]; then
        cd "$PATH_FLAC" || { echo "Error: Directory $PATH_FLAC not found."; exit 1; }
    fi

    # Rename files if any are found
    count=1
    for flac_file in *.flac; do
        # Extract track name from CSV
        track_name=$(echo "$TRACK_LIST" | sed -n "${count}p" | awk -F, '{print $8,$9}')
        
        if [ -z "$track_name" ]; then
            echo "Error: Track name is empty for track $count. Skipping..."
            ((count++))
            continue
        fi

        # Create the new filename
        new_filename="${track_name}.flac"

        # Rename the file
        if [ "$flac_file" != "$new_filename" ]; then
            echo "Renaming '$flac_file' to '$new_filename'"
            mv "$flac_file" "$new_filename"
        else
            echo "Track $count already named correctly as '$new_filename'"
        fi
        ((count++))
    done
}

# Run the main function
main "$@"

