#!/bin/bash
export STORAGE_TYPE="s3"
export S3_ENDPOINT="xxx.r2.cloudflarestorage.com"
export S3_ACCESS_KEY="AK"
export S3_SECRET_KEY="SK"
export S3_BUCKET="bucket"
export S3_PATH="my-path/folder"

if [ -n "$STORAGE_TYPE" ]; then
    if [ "$STORAGE_TYPE" = "s3" ]; then
        if [ -z "$S3_ENDPOINT" ] || [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_BUCKET" ]; then
            echo "Error missing s3"
            exit 1
        fi
        S3_PROVIDER="Other"
        if [[ "$S3_ENDPOINT" == *"cloudflarestorage"* ]]; then
            S3_PROVIDER="Cloudflare"
            S3_REGION="${S3_REGION:-auto}"
        else
            S3_REGION="${S3_REGION:-us-east-1}"
        fi
        
        if [[ ! "$S3_ENDPOINT" =~ ^https?:// ]]; then
            S3_ENDPOINT="https://$S3_ENDPOINT"
        fi
        
        S3_PATH_STR=""
        if [ -n "$S3_PATH" ]; then
            S3_PATH_STR="${S3_PATH#/}"
            if [ -n "$S3_PATH_STR" ] && [ "${S3_PATH_STR: -1}" != "/" ]; then
                S3_PATH_STR="$S3_PATH_STR/"
            fi
        fi
        # Wait, if S3_PATH_STR is "folder/", then "$S3_BUCKET/$S3_PATH_STR" is "bucket/folder/". Wait, rclone doesn't need trailing slash, but we just need "$S3_BUCKET/$S3_PATH_STR" to be "bucket/folder".
        echo ":s3,provider=\"$S3_PROVIDER\",region=\"$S3_REGION\",endpoint=\"$S3_ENDPOINT\",access_key_id=\"$S3_ACCESS_KEY\",secret_access_key=\"$S3_SECRET_KEY\":$S3_BUCKET/$S3_PATH_STR"
    fi
fi
