#!/bin/bash
set -e

if [ $# -ne 1 ]; then
  >&2 echo "Usage: recall_file.sh </path/to/recall>"
  exit 1
fi

ROOT_DIR=${ROOT_DIR:-"/storage/disk"}
TAPE_DIR=${TAPE_DIR:-"/storage/tape"}
STORM_TAPE_ROOT_DIR="/tmp/disk"
PIN_TIME=${PIN_TIME:-21600}

file="$1"
# Relative path with respect to STORM_TAPE_ROOT_DIR
REL_PATH="${file#$STORM_TAPE_ROOT_DIR/}"

SRC_FILE="$TAPE_DIR/$REL_PATH"
DST_FILE="$ROOT_DIR/$REL_PATH"

echo "Recalling "$DST_FILE" on disk"

if (( RANDOM % 100 > 7 )); then
  cp "$SRC_FILE" "$DST_FILE"
else
  echo "Unable to copy the file $DST_FILE from Tape"
  exit 1
fi

if (( RANDOM % 100 > 7 )); then
  attr -r TSMRecT "$DST_FILE"
else
  echo "Unable to remove the extended attribute TSMRecT from file $DST_FILE"
  exit 1
fi

now=$(date +%s)
expdate=$(($now+$PIN_TIME))

if (( RANDOM % 100 > 7 )); then
  attr -s storm.pinned -V $expdate "$DST_FILE"
else
  echo "Unable to add pin to file $DST_FILE"
  exit 1
fi