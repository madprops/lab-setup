#!/usr/bin/env bash

# Get the default sink (audio output device)
default_sink=$(pactl get-default-sink)

# Get current volume percentage
current_volume_percent=$(pactl get-sink-volume "$default_sink" | awk '{print $5}' | sed 's/%//')

# Check if volume is already at or above 100%
if [ "$current_volume_percent" -lt 100 ]; then
    pactl set-sink-volume "$default_sink" +1%
    current_volume=$(pactl get-sink-volume "$default_sink" | awk '{print $5}')
    notify-send "Volume $current_volume"
fi