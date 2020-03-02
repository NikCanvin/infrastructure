#!/bin/bash

SCRIPT_LOCT=`dirname $0`
SCRIPT_LOCT=`cd $SCRIPT_LOCT; pwd`
cd $SCRIPT_LOCT

if [ -z "$1" ]; then
	>&2 echo "Error: Restic tag to restore is not specified"
	exit 1
fi
RESTIC_VOLUME_TAG="$1"

# Perform restore to temporary directory

export RESTIC_REPOSITORY="s3:s3.us-east.cloud-object-storage.appdomain.cloud/codewind-backup"
EXTRACT_DIR=`mktemp -d`

RESTIC_SNAPSHOTS_OUTPUT=`snap run restic snapshots -c --last --tag "$RESTIC_VOLUME_TAG"`
ERROR_CODE=$?
if [[ $ERROR_CODE -ne 0 ]]; then
	>&2 echo "* Error code on restic snapshots was non-zero: $RESTIC_SNAPSHOT_ID"
	exit 1
fi

RESTIC_SNAPSHOT_ID=`printf %s "$RESTIC_SNAPSHOTS_OUTPUT" | grep "$RESTIC_VOLUME_TAG" | cut -d' ' -f1 | tail -n1`
if [ -z "$RESTIC_SNAPSHOT_ID" ]; then
	>&2 echo "No restic snapshot found. Exiting."
	exit 200
fi

# Capture the stdout as a variable; stderr is intentionally not captured
RESTIC_OUTPUT=`snap run restic restore -t $EXTRACT_DIR $RESTIC_SNAPSHOT_ID`
ERROR_CODE=$?
if [[ $ERROR_CODE -ne 0 ]]; then
	>&2 echo "* Error code on restic restore was non-zero: $RESTIC_OUTPUT.  Snapshot output: $RESTIC_SNAPSHOTS_OUTPUT. Snapshot ID: $RESTIC_SNAPSHOT_ID"
	exit 1
fi


TAR_NAME=`ls $EXTRACT_DIR/tmp/*.bz2`
if [[ $ERROR_CODE -ne 0 ]]; then
	>&2 echo "* Error code on ls temp dir contents was non-zero: $RESTIC_OUTPUT"
	exit 1
fi

# Output location of restored tar file
echo $TAR_NAME

