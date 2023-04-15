#!/bin/bash
set -euo pipefail

partition_device="$(findmnt -no SOURCE /)"
partition_number="$(echo "$partition_device" | perl -ne '/(\d+)$/ && print $1')"
disk_device="$(echo "$partition_device" | perl -ne '/(.+?)\d+$/ && print $1')"

# resize the partition table.
parted ---pretend-input-tty "$disk_device" <<EOF
resizepart $partition_number 100%
yes
EOF

# resize the file system.
resize2fs "$partition_device"
