/usr/sbin/daemon -o /usr/local/vidar/logs/run_ipfw.log /bin/sh -c 'sleep 2; . /usr/local/vidar/etc/vidar_env.sh ; /usr/local/vidar/scripts/ipfw_up.sh'
