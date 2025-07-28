#!/usr/bin/env bash

# Get the default sink (audio output device)
default_sink=$(pactl get-default-sink)

# Decrease volume by 1%
pactl set-sink-volume "$default_sink" -1%

current_volume=$(pactl get-sink-volume "$default_sink" | awk '{print $5}')
notify-send "Volume $current_volume"