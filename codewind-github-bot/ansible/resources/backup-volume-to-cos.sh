#!/bin/bash

set -eo pipefail

SCRIPT_LOCT=`dirname $0`
SCRIPT_LOCT=`cd $SCRIPT_LOCT; pwd`

cd $SCRIPT_LOCT

if [ -z "$1" ]; then
	echo "Error: Source volume is not specified"
	exit 1
fi
SOURCE_VOLUME=$1

if [ -z "$2" ]; then
	echo "Error: Restic tag name is not specified."
	exit 1
fi
RESTIC_TAG_NAME=$2

if [ "$DISABLE_BACKUPS" == "true" ]; then
	echo "Error: Backups are disabled, so returning from $0."
	exit 0
fi


# Do the actual backup ---------------------------------------------------------------------------

# Disable error checking
set +euo pipefail

ARCHIVE_FILENAME=`./backup-volume-to-archive.sh $SOURCE_VOLUME`
ERROR_CODE=$?
if [[ $ERROR_CODE -eq 200 ]]; then
	echo "* No volume with name $SOURCE_VOLUME, so exiting. "
	exit 0
fi

if [[ $ERROR_CODE -gt 0 ]]; then
	>&2 echo "* Unexpected return code from backup volume to archive: $ERROR_CODE"
	exit 1
fi

export RESTIC_REPOSITORY="s3:s3.us-east.cloud-object-storage.appdomain.cloud/codewind-backup"

>&2 echo "* Ignore errors 'requested bucket name is not available' and 'repository master key and config already initialized'. They are expected and are presented here for debug purposes only."

/snap/bin/aws --endpoint-url https://s3.us-east.cloud-object-storage.appdomain.cloud --region=us-east-standard  s3 mb s3://codewind-backup
snap run restic init

#aws --endpoint-url https://s3.us-east.cloud-object-storage.appdomain.cloud --region=us-east-vault  s3 mb s3://jgw-bucket2

# Re-enable error checking

set -euo pipefail

>&2 echo "* Errors after this message are valid."

snap run restic backup --tag $RESTIC_TAG_NAME $ARCHIVE_FILENAME

rm -f $ARCHIVE_FILENAME

