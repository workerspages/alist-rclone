#!/bin/bash
parse_url() {
    SYNC_DEST="$1"
    if [[ "$SYNC_DEST" =~ ^s3://([^:]+):([^@]+)@([^/]+)/(.*)$ ]]; then
        S3_AK="${BASH_REMATCH[1]}"
        S3_SK="${BASH_REMATCH[2]}"
        S3_ENDPOINT="${BASH_REMATCH[3]}"
        S3_BUCKET="${BASH_REMATCH[4]}"
        S3_PROVIDER="Other"
        if [[ "$S3_ENDPOINT" == *"cloudflarestorage"* ]]; then
            S3_PROVIDER="Cloudflare"
        fi
        if [[ ! "$S3_ENDPOINT" =~ ^https?:// ]]; then
            S3_ENDPOINT="https://$S3_ENDPOINT"
        fi
        echo ":s3,provider=\"$S3_PROVIDER\",endpoint=\"$S3_ENDPOINT\",access_key_id=\"$S3_AK\",secret_access_key=\"$S3_SK\":$S3_BUCKET"
    elif [[ "$SYNC_DEST" =~ ^(webdav|dav)://([^:]+):([^@]+)@(.*)$ ]]; then
        DAV_USER="${BASH_REMATCH[2]}"
        DAV_PASS="${BASH_REMATCH[3]}"
        DAV_PATH="${BASH_REMATCH[4]}"
        if [[ ! "$DAV_PATH" =~ ^https?:// ]]; then
            DAV_ENDPOINT="https://$DAV_PATH"
        else
            DAV_ENDPOINT="$DAV_PATH"
        fi
        OBSCURED_PASS="dummy_obscured_$DAV_PASS"
        echo ":webdav,vendor=\"other\",url=\"$DAV_ENDPOINT\",user=\"$DAV_USER\",pass=\"$OBSCURED_PASS\":"
    else
        echo "$SYNC_DEST"
    fi
}
parse_url "s3://AK123:SK456@my.r2.cloudflarestorage.com/my-bucket"
parse_url "webdav://admin:pass123@dav.jianguoyun.com/dav/alist"
parse_url "dav://user:pass@https://nextcloud.com/remote.php/webdav/backup"
parse_url ":s3,provider=AWS:bucket"
