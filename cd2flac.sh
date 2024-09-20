#!/bin/bash

# Check if argument is provided, if not, show help message
if [ -z "$1" ]; then
  echo "Usage: sh cd2flac.sh <CD_IDENTIFIER>"
  echo "Example: sh cd2flac.sh '0630-18677-2'"
  exit 1
fi

# Check for cdparanoia and flac
if ! command -v cdparanoia &> /dev/null; then
  echo "cdparanoia is not installed."
  exit 1
fi

if ! command -v flac &> /dev/null; then
  echo "flac is not installed."
  exit 1
fi

# Rip CD to AIFF and convert to FLAC
cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log

# Call the Python script with the CD identifier as an argument
python3 meta2flac.py "$1"

#
