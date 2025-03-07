#!/bin/bash

# clean spotlight
# mdutil -d $1
# mdutil -X $1

# clean some files
find "$1" -type f -name '._*' -exec rm -r {} \;
find "$1" -type f -name '.DS_Store' -exec rm -r {} \;
