import os
import csv
import subprocess
import sys
import argparse

# Path to your CSV metadata file
METADATA_CSV = 'csv/music.csv'

# Base directory to store the ripped FLAC files
FLAC_BASE_DIR = './flac_files/'

# Function to display help menu
def display_help():
    print("""
    Usage:
    python3 cd2flac.py <catalog_number>

    Arguments:
    catalog_number  The catalog number of the media, used to find metadata in csv/music.csv.

    Example:
    python3 cd2flac.py 'CDP 7 46435 2'
    """)

# Function to check if CD drive is detected
def check_cd_drive():
    try:
        result = subprocess.run(['cdparanoia', '-Q'], capture_output=True, text=True)
        if 'Disc detected' in result.stdout:
            print("CD detected.")
            return True
        else:
            print("No CD detected. Please insert a CD.")
            return False
    except FileNotFoundError:
        print("cdparanoia not installed. Please install it.")
        return False

# Function to rip CD to WAV format using cdparanoia
def rip_cd_to_wav():
    if not os.path.exists('wav_files'):
        os.makedirs('wav_files')

    print("Ripping CD to WAV format...")
    subprocess.run(['cdparanoia', '-B'], check=True)
    print("CD ripped to WAV format.")

# Function to convert WAV files to FLAC and apply metadata
def convert_wav_to_flac(metadata=None):
    if not metadata:
        print("No metadata found. FLAC files will be created without metadata.")
        metadata = [{'track_number': f'{i+1:02}', 'title': f'Track {i+1}', 'artist': 'Unknown Artist',
                     'album': 'Unknown Album', 'year': 'Unknown Year', 'genre': 'Unknown Genre'}
                    for i in range(len([f for f in os.listdir('wav_files') if f.endswith('.wav')]))]

    album_artist = metadata[0].get('albumartist', metadata[0].get('artist', 'Unknown Artist'))
    album = metadata[0].get('album', 'Unknown Album')
    year = metadata[0].get('year', 'Unknown Year')

    # Create the directory structure: flac/Artist/Album (Year)
    album_dir = os.path.join(FLAC_BASE_DIR, f"{album_artist}/{album} ({year})")
    if not os.path.exists(album_dir):
        os.makedirs(album_dir)

    wav_files = sorted([f for f in os.listdir('wav_files') if f.endswith('.wav')])

    for idx, wav_file in enumerate(wav_files):
        # Get metadata for the current track
        meta = metadata[idx]
        track_number = meta.get('track_number', f'{idx + 1:02}')
        title = meta.get('title', f'Track {idx + 1}')
        artist = meta.get('artist', 'Unknown Artist')
        album = meta.get('album', 'Unknown Album')
        genre = meta.get('genre', 'Unknown Genre')
        year = meta.get('year', 'Unknown Year')

        flac_file = os.path.join(album_dir, f'{track_number} - {title}.flac')
        cmd = [
            'flac', f'wav_files/{wav_file}',
            '--best',
            '--output-name', flac_file,
            '--tag', f'ARTIST={artist}',
            '--tag', f'ALBUM={album}',
            '--tag', f'TITLE={title}',
            '--tag', f'TRACKNUMBER={track_number}',
            '--tag', f'GENRE={genre}',
            '--tag', f'YEAR={year}',
        ]
        print(f'Converting {wav_file} to {flac_file}...')
        subprocess.run(cmd, check=True)
        print(f'FLAC file created: {flac_file}')

    print("All WAV files converted to FLAC.")

# Function to parse metadata from CSV
def parse_metadata_from_csv(catalog_number):
    metadata = []
    with open(METADATA_CSV, mode='r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            if row['catalog_number'] == catalog_number:
                metadata.append(row)
    return metadata

# Function to remove temporary WAV files
def cleanup_wav_files():
    print("Cleaning up WAV files...")
    wav_files = [f for f in os.listdir('wav_files') if f.endswith('.wav')]
    for wav_file in wav_files:
        os.remove(os.path.join('wav_files', wav_file))
    print("WAV files cleaned up.")

# Main function to run the full process
def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Rip CD and convert to FLAC with metadata.')
    parser.add_argument('catalog_number', nargs='?', help='Catalog number of the CD for metadata lookup')
    args = parser.parse_args()

    if not args.catalog_number:
        display_help()
        sys.exit(1)

    if not check_cd_drive():
        sys.exit(1)

    # Rip CD to WAV files
    rip_cd_to_wav()

    # Parse metadata from the CSV file
    metadata = parse_metadata_from_csv(args.catalog_number)

    if not metadata:
        print(f"Catalog number '{args.catalog_number}' not found in {METADATA_CSV}.")
        proceed = input("Continue without metadata? (y/n): ").lower()
        if proceed != 'y':
            print("Aborting operation.")
            sys.exit(1)

    # Convert WAV files to FLAC with metadata
    convert_wav_to_flac(metadata)

    # Cleanup WAV files after conversion
    cleanup_wav_files()

if __name__ == '__main__':
    main()
    
#
