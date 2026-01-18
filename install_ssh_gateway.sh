#!/usr/bin/env bash
if ! $(cat values.yaml | grep -A1 "ssh:" | grep "enabled" | awk -F: '{print $2}') = "true"; then
	echo "Must enable ssh first in values.yaml."
	exit 0
fi
printf "%s\n" 1 1 "y" | ./install.sh
