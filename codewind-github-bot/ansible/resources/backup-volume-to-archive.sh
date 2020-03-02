#!/bin/bash

set -eo pipefail

export SCRIPT_LOCT=`dirname $0`
export SCRIPT_LOCT=`cd $SCRIPT_LOCT; pwd`

cd $SCRIPT_LOCT

if [ -z "$1" ]; then
	echo "Error: Source volume is not specified"
	exit 1
fi
SOURCE_VOLUME=$1

# Check if the volume exists, if not, no need to backup ------------------------------------------

set -eou pipefail

NUM_VOLUMES=`docker volume ls`

# Temporarily turn off the shell script modes, because grep returns an error code on non-match
set +euo pipefail
NUM_VOLUMES=`printf %s "$NUM_VOLUMES" | grep "$SOURCE_VOLUME" | wc -l`

if [ "$NUM_VOLUMES" != "1" ]; then
    echo "* Volume '$SOURCE_VOLUME' does not exist, so exiting."
    exit 200
fi

# Do the actual backup ---------------------------------------------------------------------------

# `cat /dev/urandom` returns a non-zero error code, for some reason...

ARCHIVE_FILENAME=volume-backup-`cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32`.tar.bz2

ARCHIVE_FILENAME2=volume-backup-`cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32`.tar.bz2

set -euo pipefail

docker run --rm -v $SOURCE_VOLUME:/volume -v /tmp:/backup alpine \
    sh -c -e "tar -cjf /backup/$ARCHIVE_FILENAME -C /volume ./ ; chmod a+r /backup/$ARCHIVE_FILENAME"

cp /tmp/$ARCHIVE_FILENAME /tmp/$ARCHIVE_FILENAME2

docker run --rm -v /tmp:/backup alpine rm -f /backup/$ARCHIVE_FILENAME

echo "/tmp/$ARCHIVE_FILENAME2"

