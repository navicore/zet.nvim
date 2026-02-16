#!/bin/bash
#
# tmux-reminder-popup.sh - Open nvim with Zet reminder_scan in a tmux popup
#
# Usage: tmux-reminder-popup.sh
#
# Add to tmux.conf:
#   bind r run-shell "/path/to/tmux-reminder-popup.sh"
#

# Open tmux popup with nvim running Zet reminder_scan
# -E closes popup when nvim exits
# -w and -h set width/height as percentage
tmux popup -E -w 80% -h 80% nvim -c "Zet reminder_scan"
