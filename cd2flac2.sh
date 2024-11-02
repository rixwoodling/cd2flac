#!/bin/bash

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

# Function to check CD detection
check_cd_inserted() {
    udevadm info --query=all --name=/dev/sr0 | grep -q 'ID_CDROM_MEDIA=1'
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
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $(echo "$matches" | wc -l) ]; then
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
    if [ -z "$1" ]; then
        echo "Usage: sh cd2flac.sh <CD_IDENTIFIER>"
        echo "Example: sh cd2flac.sh '0630-18677-2'"
        exit 1
    fi

    check_prerequisites

    argument=$(grep -i "$1" csv/music.csv)
    if [ -z "$argument" ]; then
        echo "no matches found for '$1' in csv/music.csv"
        exit 1
    fi

    matches=$(get_matches "$argument")
    selected_line=$(select_album "$matches")

    # Parse values
    ALBUM_ARTIST=$(echo "$selected_line" | awk -F' - ' '{print $1}')
    ALBUM_YEAR_ATTR=$(echo "$selected_line" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//')

    # Create directories if not present
    PATH_FLAC="flac/$ALBUM_ARTIST/$ALBUM_YEAR_ATTR"
    mkdir -p "$PATH_FLAC"

    if check_cd_inserted; then
        echo "CD detected, checking track totals..."
        # Ensure track totals match before ripping
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
}

# Run the main function
main "$@"

