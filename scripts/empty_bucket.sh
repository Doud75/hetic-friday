#!/bin/bash
BUCKET=$1
if [ -z "$BUCKET" ]; then
    echo "Usage: $0 <bucket_name>"
    exit 1
fi

echo "Removing all versions from $BUCKET..."
versions=$(aws s3api list-object-versions --bucket "$BUCKET" --output=json --query="{Objects: Versions[].{Key:Key,VersionId:VersionId}}")
markers=$(aws s3api list-object-versions --bucket "$BUCKET" --output=json --query="{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}")

if [ "$versions" != "null" ] && [ "$versions" != '{"Objects": null}' ] && [ "$versions" != '{"Objects": []}' ]; then
    echo "Deleting versions..."
    echo "$versions" > versions.json
    aws s3api delete-objects --bucket "$BUCKET" --delete file://versions.json
    rm versions.json
fi

if [ "$markers" != "null" ] && [ "$markers" != '{"Objects": null}' ] && [ "$markers" != '{"Objects": []}' ]; then
    echo "Deleting delete markers..."
    echo "$markers" > markers.json
    aws s3api delete-objects --bucket "$BUCKET" --delete file://markers.json
    rm markers.json
fi

echo "Bucket $BUCKET is now empty."
