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
    fi     
}

# Function to select album
function choose_album() {
    if [ $(echo "$HITS" | wc -l) -eq 1 ]; then
        echo "$HITS" | nl
        read -p "confirm [Y/n]? " CONFIRM
        CONFIRM=${CONFIRM:-Y}  # Default to 'Y' if Enter is pressed
        if [[ "$CONFIRM" =~ ^[Yy1]$ ]]; then
            MATCH="$HITS"
        else
            echo "Invalid selection. Cancelled. :("
            exit 1
        fi
    else
        echo "$HITS" | nl
        echo -n "select 1-$(echo "$HITS" | nl | wc -l): "
        read -r SELECTION
        if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [[ "$SELECTION" -lt 1 ]] || [[ "$SELECTION" -gt $(echo "$HITS" | wc -l) ]]; then
            echo "invalid selection. exiting. :("
            exit 1
        fi
        MATCH="$(echo "$HITS" | sed -n "${SELECTION}p")"
    fi
}

function get_albumartist() {
    ALBUM_ARTIST=$(echo "$MATCH" | awk -F' - ' '{print $1}')
}

function get_album() {
    ALBUM=$(echo "$MATCH" | awk -F' - ' '{sub($1 FS, ""); print}' | rev | sed 's/.*( //' | rev)
}

function get_year() {
    YEAR=$(echo "$MATCH" | rev | sed 's/.*)//' | sed 's/(.*//' | rev)
}

function get_attributes() {
    ATTRIBUTES=$(echo "$MATCH" | rev | sed 's/).*//' | rev | sed 's/.*\[//' | sed 's/\].*//' | sed 's/[[:space:]]\+$//')
}

function get_albumyearattr() {
    ALBUM_YEAR_ATTR=$(echo "$MATCH" | awk -F' - ' '{print $2}' | sed 's/[[:space:]]\+$//')
}

function get_disc_total() {
    DISC_TOTAL=$(cat csv/music.csv | grep "$ALBUM_ARTIST" | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | awk -F',' '{print $7}' | uniq | wc -l)
}    

function get_disc_number() {
    if [ $DISC_TOTAL -gt 1 ]; then
        disc_list=$(grep "$ALBUM_ARTIST" csv/music.csv | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | sed 's/, /__/' | awk -F',' '{print $3" - "$5" ("$6") "$13" CD"$7}' | uniq | nl)
        echo "$disc_list"
        echo -n "Select disc: "
        read -r DISC_SELECT
        if ! [[ "$DISC_SELECT" =~ ^[0-9]+$ ]] || [[ "$DISC_SELECT" -lt 1 ]] || [[ "$DISC_SELECT" -gt $(echo "$disc_list" | wc -l) ]]; then
            echo "invalid selection. exiting. :("
            exit 1
        fi
        DISC_NUMBER="$(echo "$disc_list" | sed -n "${DISC_SELECT}p")"
        DISC_NUMBER=$DISC_SELECT
    else
        DISC_NUMBER=1
    fi    
}

function get_track_total() {
    TRACK_TOTAL=$(cat csv/music.csv | grep "$ALBUM_ARTIST" | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | awk -F',' '{print $7}' | grep $DISC_NUMBER | wc -l)
}

# ---

# Function to check CD detection
function detect_cd() {
    udevadm info --query=all --name=/dev/sr0 2>/dev/null | grep -q 'ID_CDROM_MEDIA=1' &>/dev/null
    if [ $? -eq 0 ]; then 
        CD_DETECTION="Yes"
    else
        CD_DETECTION="No"
    fi    
}

function cd_tracktotal() {
    CD_TRACKTOTAL=$(cdparanoia -Q 2>&1 | awk '{print $1}' | grep "^[ 0-9]" | wc -l)
}

function sanitize_directory_name() {
    echo "$1" | sed 's/^[.]*//'
}

# Function to create flac directory and sanitized album artist subdirectory
function define_output_directory() {
    # Sanitize album artist and album names
    FILTERED_ALBUM_ARTIST=$(sanitize_directory_name "$ALBUM_ARTIST")
    FILTERED_ALBUM=$(sanitize_directory_name "$ALBUM")
    # Construct the full directory path, handling optional attributes
    if [ ! -z "$ATTRIBUTES" ]; then
        OUTPUT_PATH="flac/$FILTERED_ALBUM_ARTIST/$FILTERED_ALBUM ($YEAR) [$ATTRIBUTES]"
    else
        OUTPUT_PATH="flac/$FILTERED_ALBUM_ARTIST/$FILTERED_ALBUM ($YEAR)"
    fi
}

function verify_output_path() {
    if [ -d "$OUTPUT_PATH" ]; then
        OUTPUT_PATH_EXISTS="Yes"
    else
        OUTPUT_PATH_EXISTS="No"
    fi
}

function get_flac_total() {
    # return flac count found in output path
    FLAC_TOTAL=$(ls "$OUTPUT_PATH" 2>/dev/null | grep ".flac" | wc -l)
}

function detect_multiple_artists() {
    ARTIST_TOTAL=$(grep "$ALBUM_ARTIST" csv/music.csv | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | sed 's/, /__/' | awk -F',' '{print $4}' | wc -l)
    if [ $ARTIST_TOTAL -gt 1 ]; then
        ARTIST_TOTAL="Yes"
    else
        ARTIST_TOTAL="No"
    fi      
}

function final_checks() {
    # check if cd inserted, return value 0 or 1
    udevadm info --query=all --name=/dev/sr0 2>/dev/null | grep -q 'ID_CDROM_MEDIA=1' &>/dev/null
    check_cd_inserted=$?

    # if cd inserted, return track total, otherwise return 0
    if [ $check_cd_inserted -eq 0 ]; then
        CD_TRACKTOTAL=$(cdparanoia -Q 2>&1 | awk '{print $1}' | grep "^[ 0-9]" | wc -l)
    else
        CD_TRACKTOTAL=0
    fi

    # return track total matching non-filtered results ( should be > 0 )
    tracktotal_in_csv=$(grep "$ALBUM_ARTIST" csv/music.csv | grep "$ALBUM" | grep "$YEAR" | grep "$ATTRIBUTES" | wc -l)

    # if track total found in csv matches cd track total, then return match value 0, otherwise return 1
    if [ $tracktotal_in_csv -eq $CD_TRACKTOTAL ]; then
        csv_match_boolean=0
    else
        csv_match_boolean=1
    fi


    # if flac files not in output_path, CD inserted, start ripping
    #if [ cd_status -eq 0 ]; then
    # if flac files not in output_path, and CD not inserted, error with nothing to do
    # if flac files in output_path, and CD not inserted, and flac files match csv, rewrite metadata
    # if flac files in output_pathy, and CD not inserted, and flac files don't match csv, error with mismatch
    # if flac files in output_path, and CD inserted, and CD total matches csv, error with files exist
    # if flac files in output_path, and CD inserted, and CD total doesn't match csv, error with CD/csv mismatch
}



# Function to rip CD
function rip_cd() {
    echo "Start Ripping... ;)"
    pushd "$OUTPUT_PATH" > /dev/null
    cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
    cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
    flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log
    popd > /dev/null
}

function debug() {
    echo
    printf "Album Artist:\t\t$ALBUM_ARTIST\n"
    printf "Album:\t\t\t$ALBUM\n"
    printf "Year:\t\t\t$YEAR\n"
    printf "Attributes:\t\t$ATTRIBUTES\n"
    printf "Disc Total:\t\t$DISC_TOTAL\n"
    printf "Disc Number:\t\t$DISC_NUMBER\n"
    printf "Track Total:\t\t$TRACK_TOTAL\n"
    printf "Filtered Album Artist:\t$FILTERED_ALBUM_ARTIST\n"
    printf "Filtered Album Artist:\t$FILTERED_ALBUM\n"
    printf "File Path:\t\t$OUTPUT_PATH/\n"
    printf "File Path Exists:\t$OUTPUT_PATH_EXISTS\n"
    printf "Flac Total:\t\t$FLAC_TOTAL\n"
    printf "Multiple Artists:\t$ARTIST_TOTAL\n"

    printf "\n( o )\n"
    printf "CD Detected:\t\t$CD_DETECTION\n"
    printf "CD Track Total:\t\t$CD_TRACKTOTAL\n"
}

# Main function
main() {
    help "$1" # run help, exit if argument is blank or help flags called
    check_prerequisites # then check if csv databases exist, and cdparanoia, flac installed
    get_matches "$1" # return a list of formatted matches
    choose_album
    
    get_albumartist
    get_album
    get_year
    get_attributes
    get_disc_total
    get_disc_number
    get_track_total
    define_output_directory    
    verify_output_path
    get_flac_total

    detect_multiple_artists
    
    detect_cd

    final_checks
    
    #if [ $flac_count -eq 0 ]; then
    #    echo "directory is empty"
    #else
    #    echo "directory is not empty"
    #fi
    debug
    #check_cd_inserted
    #if check_cd_inserted; then
    #    echo "0"
        #create_output_path
        #check_path_for_flac
        #if ! check_path_for_flac; then
            #rip_cd()
    #else
    #    echo "1"
    #fi    
    

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

