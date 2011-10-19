echo "- module get_resources loaded"
uname -a
uptime
free -t
df -P -T
which smartctl > /dev/null && test -b /dev/sda && smartctl -a /dev/sda
