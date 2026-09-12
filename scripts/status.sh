#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  printf 'Usage: %s MOUNTPOINT UUID DEVICE_1_PARTITION SERIAL_1 DEVICE_2_PARTITION SERIAL_2\n' "$0" >&2
  exit 2
fi

mountpoint=$1
expected_uuid=$2
device_1_partition=$3
expected_serial_1=$4
device_2_partition=$5
expected_serial_2=$6
sysfs=/sys/fs/btrfs/$expected_uuid

[[ $device_1_partition == /dev/disk/by-id/*-part1 ]]
[[ $device_2_partition == /dev/disk/by-id/*-part1 ]]

actual_uuid=$(findmnt -n -o UUID -T "$mountpoint")
actual_fstype=$(findmnt -n -o FSTYPE -T "$mountpoint")
device_1_parent=$(lsblk -npo PKNAME "$device_1_partition")
device_2_parent=$(lsblk -npo PKNAME "$device_2_partition")
canonical_partition_1=$(realpath "$device_1_partition")
canonical_partition_2=$(realpath "$device_2_partition")
actual_serial_1=$(lsblk -dn -o SERIAL "$device_1_parent")
actual_serial_2=$(lsblk -dn -o SERIAL "$device_2_parent")
member_1=$(basename "$canonical_partition_1")
member_2=$(basename "$canonical_partition_2")
members=("$sysfs"/devices/*)
devinfo_entries=("$sysfs"/devinfo/*)

[[ $actual_uuid == "$expected_uuid" ]]
[[ $actual_fstype == btrfs ]]
[[ $canonical_partition_1 != "$canonical_partition_2" ]]
[[ $device_1_parent != "$device_2_parent" ]]
[[ $member_1 != "$member_2" ]]
[[ $expected_serial_1 != "$expected_serial_2" ]]
[[ $actual_serial_1 == "$expected_serial_1" ]]
[[ $actual_serial_2 == "$expected_serial_2" ]]
[[ ${#members[@]} -eq 2 ]]
[[ ${#devinfo_entries[@]} -eq 2 ]]
[[ -e $sysfs/devices/$member_1 ]]
[[ -e $sysfs/devices/$member_2 ]]

for entry in "${devinfo_entries[@]}"; do
  [[ $(<"$entry/missing") == 0 ]]
  [[ $(<"$entry/in_fs_metadata") == 1 ]]
done

date '+%Y-%m-%d %H:%M:%S %Z'
printf '\nFilesystem identity:\n'
printf 'mountpoint=%s\nuuid=%s\nfilesystem=%s\n' \
  "$mountpoint" "$actual_uuid" "$actual_fstype"
printf 'device_1_serial=%s\ndevice_2_serial=%s\n' \
  "$actual_serial_1" "$actual_serial_2"
printf 'members=%s,%s\n' "$member_1" "$member_2"
printf '\nExclusive operation:\n'
printf '%s\n' "$(<"$sysfs/exclusive_operation")"
printf '\nProfiles:\n'
btrfs filesystem df -b "$mountpoint"
printf '\nFilesystem usage:\n'
btrfs filesystem usage -b "$mountpoint"
printf '\nDevice errors:\n'
btrfs device stats -c "$mountpoint"
printf '\nCapacity:\n'
df -B1 --output=source,fstype,size,used,avail,pcent,target "$mountpoint"
printf '\nRecent kernel messages:\n'
journalctl -k -b --since '10 minutes ago' \
  -g "BTRFS|$member_1|$member_2|Buffer I/O|I/O error|critical" --no-pager
