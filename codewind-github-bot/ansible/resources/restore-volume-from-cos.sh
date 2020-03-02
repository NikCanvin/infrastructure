#!/bin/bash

export SCRIPT_LOCT=`dirname $0`
export SCRIPT_LOCT=`cd $SCRIPT_LOCT; pwd`

cd $SCRIPT_LOCT

if [ -z "$1" ]; then
	>&2 echo "Error: Restic tag to restore is not specified"
	exit 1
fi
TAG_TO_RESTORE=$1

if [ -z "$2" ]; then
	>&2 echo "Error: Volume name to restore is not specified"
	exit 1
fi
VOLUME_TO_RESTORE=$2

if [ -z "$3" ]; then
	>&2 echo "Error: Container image to restore with not specified"
	exit 1
fi
CONTAINER_IMAGE_TO_RESTORE_WITH=$3

if [ -z "$4" ]; then
	>&2 echo "Error: Container user to restore with is not specified"
	exit 1
fi
CONTAINER_USER_TO_RESTORE_WITH=$4

# ------ End of param checking section -------===


set -euo pipefail

NUM_VOLUMES=`docker volume ls`

# Temporary turn off the shell script modes, because grep returns an error code on non-match
set +euo pipefail
NUM_VOLUMES=`printf %s "$NUM_VOLUMES" | grep "$VOLUME_TO_RESTORE" | wc -l`

if [ "$NUM_VOLUMES" != "0" ]; then
	echo "* Volume '$VOLUME_TO_RESTORE' already exists, exiting."	
	exit 0
fi

echo "* Calling copy-latest-cos-archive-to-local.sh"

RESTORED_ARCHIVE_PATH=`./copy-latest-cos-archive-to-local.sh $TAG_TO_RESTORE`
ERROR_CODE=$?
if [[ $ERROR_CODE -eq 200 ]]; then
	echo "* No cloud archives found, so exiting. Output: $RESTORED_ARCHIVE_PATH"
	exit 0
elif [[ $ERROR_CODE -ne 0 ]]; then
	echo "* Non-successfull error code from copy latest COS archive: $RESTORED_ARCHIVE_PATH"
	exit 1
fi

set -euo pipefail

echo "* Temporary archive path is $RESTORED_ARCHIVE_PATH"

# This is a no-op if the volume already exists.
docker volume create $VOLUME_TO_RESTORE

# We run each shell script separately, so that we can detect a non-zero error code from each.

docker run -it -u="root" --rm -v $VOLUME_TO_RESTORE:/volume --entrypoint "/bin/sh" $CONTAINER_IMAGE_TO_RESTORE_WITH \
	"-c" "chown -R $CONTAINER_USER_TO_RESTORE_WITH /volume"

docker run -it -u="root" --rm -v $VOLUME_TO_RESTORE:/volume -v $RESTORED_ARCHIVE_PATH:/tmp/restore.tar.bz2 --entrypoint "/bin/sh" $CONTAINER_IMAGE_TO_RESTORE_WITH \
	"-c" "tar -C /volume -xjf /tmp/restore.tar.bz2"

docker run -it -u="root" --rm -v $VOLUME_TO_RESTORE:/volume --entrypoint "/bin/sh" $CONTAINER_IMAGE_TO_RESTORE_WITH \
	"-c" "chown -R $CONTAINER_USER_TO_RESTORE_WITH /volume"

