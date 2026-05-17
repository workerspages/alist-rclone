#!/bin/bash
SYNC_DEST="/tmp/dest"
mkdir -p /tmp/dest
mkdir -p /data
sync_data() { echo "[AutoSync] --- Sync Started at $(date +'%Y-%m-%d %H:%M:%S') ---"; START=$(date +%s); sleep 2; END=$(date +%s); echo "[AutoSync] --- Sync Completed at $(date +'%Y-%m-%d %H:%M:%S') (Took $((END - START))s) ---"; }
sync_data
