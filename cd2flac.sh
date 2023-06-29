#!/bin/bash

cdparanoia --output-aiff --abort-on-skip --batch --log-summary && \
cdparanoia --verbose --search-for-drive --query 2>&1 | tee -a cdparanoia.log && \
flac *.aiff --verify --best --delete-input-file 2>&1 | tee -a flac.log

