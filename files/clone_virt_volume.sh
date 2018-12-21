#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Ensure that a libvirt volume does not exists.
# On success, output a JSON object with a 'changed' item.

if [[ $# -ne 3 && $# -ne 4 ]]; then
    echo "Usage: $0 <name> <newname> <pool> [<capacity>]"
    echo "       If capacity is 0 or '' image is not resized"
    exit 1
fi

NAME=$1
NEWNAME=$2
POOL=$3
CAPACITY=$4

# Check whether a destination volume exists.
output=$(virsh vol-info --pool "$POOL" --vol "$NEWNAME" 2>&1)
result=$?
if [[ "$result" -eq 0 ]]; then
    echo '{"changed": false}'
    exit 0
elif ! grep 'Storage volume not found' <<<"$output" >/dev/null 2>&1; then
    echo "Unexpected error while getting volume info"
    echo "$output"
    exit "$result"
fi

# Clone the volume.
output=$(virsh vol-clone --pool "$POOL" "$NAME" "$NEWNAME" 2>&1)
result=$?
if [[ $result -ne 0 ]]; then
    echo "Failed to clone volume $NAME to $NEWNAME"
    echo "$output"
    exit "$result"
fi

# Determine the path to the volume file.
output=$(virsh vol-key --pool "$POOL" --vol "$NEWNAME" 2>&1)
result=$?
if [[ $result -ne 0 ]]; then
    echo "Failed to get file path of volume $NEWNAME"
    echo "$output"
    virsh vol-delete --pool "$POOL" --vol "$NEWNAME"
    exit $result
fi

# Change the ownership of the volume to VOLUME_OWNER:VOLUME_GROUP if
# these environmental variables are defined. Without doing this libvirt
# cannot access the volume on RedHat based GNU/Linux distributions.
if [[ -f "$output" || -d "$output" ]]; then
    existing_owner="$(stat --format '%U' "$output")"
    existing_group="$(stat --format '%G' "$output")"
    new_owner="${VOLUME_OWNER:-$existing_owner}"
    new_group="${VOLUME_GROUP:-$existing_group}"
    output=$(chown "$new_owner":"$new_group" "$output" 2>&1)
    result=$?
    if [[ $result -ne 0 ]]; then
        echo "Failed to change ownership of volume $NEWNAME to $new_owner:$new_group"
        echo "$output"
        virsh vol-delete --pool "$POOL" --vol "$NEWNAME"
        exit $result
    fi
fi

if [[ -n "$CAPACITY" && "$CAPACITY" != "0" ]]; then
    # Resize the volume to the requested capacity
    output=$(virsh vol-resize --pool "$POOL" --vol "$NEWNAME" --capacity "$CAPACITY" 2>&1)
    result=$?
    if [[ $result -ne 0 ]]; then
        echo "Failed to resize volume $NEWNAME to $CAPACITY"
        echo "$output"
        virsh vol-delete --pool "$POOL" --vol "$NEWNAME"
        exit $result
    fi
fi

echo '{"changed": true}'
exit 0
