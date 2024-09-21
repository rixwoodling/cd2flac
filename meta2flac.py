import csv
import sys

def search_cd_metadata(cd_identifier):
    # Path to the CSV file
    csv_file = 'csv/music.csv'
    
    # Open the CSV file and search for matches
    with open(csv_file, mode='r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        matches = [row for row in reader if cd_identifier in row.values()]

    # Print matches
    if matches:
        print(f"Found {len(matches)} match(es) for CD Identifier '{cd_identifier}':")
        for match in matches:
            print(match)
    else:
        print(f"No matches found for CD Identifier '{cd_identifier}'.")

if __name__ == "__main__":
    # Check if an argument was passed
    if len(sys.argv) != 2:
        print("Usage: python meta2flac.py <CD_IDENTIFIER>")
        sys.exit(1)

    # Get the CD identifier from the command line arguments
    cd_identifier = sys.argv[1]
    
    # Search for the CD metadata
    search_cd_metadata(cd_identifier)
    
#
