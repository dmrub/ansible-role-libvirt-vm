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

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <name> <newname> <pool>"
    exit 1
fi

NAME=$1
NEWNAME=$2
POOL=$3

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

echo '{"changed": true}'
exit 0
