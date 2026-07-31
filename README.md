# VIDAR - Server Protection for Internet facing FreeBSD Servers.

Vidar is a combination of programs, a PostgreSQL database, and the SEC
correlator engine that reads logfiles from authentication, email (postfix),
and web server (nginx), (and potentially any other logs) and takes action based on SEC rules to add entries
to an IPFW firewall.  In concept it is similar to fail2ban and has some
features in common with blocklistd.

SEC reads the logs in real time and based on its rules and correlations,
outputs metadata that is piped to a process that inserts the events into
a PostgreSQL database and further pipes the offending IP address
to a script that updates a table named "BAD" in IPFW.  This table
is read by IPFW rules to block offending external systems from
wreacking havoc on a FreeBSD host.

A corresponding table named GOOD contains whitelisted IP addresses
so you don't accidently lock yourself out.

\<RANT>

Are you sick and tired of seeing:
"2a03:b0c0:3:d0::402:d001 - - [31/Jan/2026:17:37:17 -0500] \x16\x03\x01\x05\xDE\x01 ..."
in your nginx logs and sick of seeing:
"Feb 20 16:36:03 jimby dovecot[59472]: imap-login: Disconnected: Connection closed (no auth attempts in 5 secs): user=<>, rip=206.168.34.125, lip=174.136.97.66, TLS: Connection closed, ..."
in your mail logs and sick of seeing:
"Feb 20 12:47:58 jimby sshd-session[47730]: Invalid user zzzz from 2607:f170:44:12::5d0 port 520"
in your authentication logs?

With Vidar, you get to put the hammer down:

  "If you abuse my system, I will shut you out. Permanently."

\</RANT>

Vidar has additional tricks - a way to dump the IPFW BAD table and a way
to import it later - you can keep this database of shame up to date on
all those miscreants and keep them away.  You can even import the BAD table
on another FreeBSD system running IPFW.  Also, there's a handy audit script
that lets you compare the entries in the database with what is actually
in the IPFW BAD table.  Also, Vidar keeps the evidence of the event
in question that resulted in blocked access.  Finally, using SEC rules,
you can make the block last for an hour (for a misconfigured remote system)
or a day (for a script kiddie), or permanently (for a determined hacker),
or any length of time you choose.

There is also a feature to check live processes and alert if, for example,
the vi editor is running at 2:00am in the morning.


## Implementation Notes

Vidar is a collection of shell and perl scripts.  It is fairly robust.
The code has been tested on a Lenovo T530 (16G RAM) with the utilities
in the ~/src/vidar/utils directory.  The code was able to keep up
with 3 different input streams (auth.log, nginx/access.log, and maillog)
at about 900 to 1000 messages per second.

## Installation Notes
Below are some installation notes.


\# login as root

pkg install postgresql18-client
pkg install postgresql18-server
pkg install perl5
pkg install sec
pkg install git
pkg install p5-DBD-Pg
pkg install p5-DBI
pkg install sudo
pkg install pstree

pkg install -yU postgresql18-client postgresql18-server perl5 sec
pkg install -yU git p5-DBD-Pg p5-DBI sudo pstree

sysrc postgresql_enable=YES

service postgresql initdb
service postgresql start

\# Check postgres & connectivity, exit with \q
psql -U postgres postgres

\# Login as root and 
\# put _your_name_ into /usr/local/etc/sudoers
\# or just enable this line if you are in wheel group:

\#\# Same thing without a password
\# %wheel ALL=(ALL:ALL) NOPASSWD: ALL
 
adduser vidar

\# Login as _your_name_  from another terminal session

cd $HOME

mkdir src && cd src

git clone https://github.com/jimmyb-gh/vidar.git

\# As user _your_name_
cd ~/src/vidar

\# Install vidar code in dev mode into /home/vidar/dev
sudo /bin/sh vidar_install.sh  dev

\# Check that code is in /home/vidar/dev

\# Then install the database
sudo ./vidar_database_init.sh

\# Answer yes to scary warning

\# Check /var/db/postgres/data18/pg_hba.conf

\# Apply vidar as peer authentication at end of  /var/db/postgres/data18/pg_hba.conf :

\# TYPE  DATABASE        USER            ADDRESS                 METHOD
\# local modifications for vidar
local       vidar           vidar                                   peer

\# Leave the rest of file is unchanged.
\# You MUST restart postgresql after this change:
service postgresql restart

\# Login or su to user vidar

cd /home/vidar/dev/etc

\#      # source the vidar_envs.sh file
\#      #SHOW_ENV="Y"
\#      #. ./vidar_env.sh

\# Check over the environment variables.
\# In particular, for a first time install,
\# the AUTHLOG, EMAILLOG, and NGINXLOG entries
\# should all be in /home/vidar/dev/input/
\#

\# As vidar, cd to ~/dev/postgres and run
sh vidar_connectiontest.sh

\# DBI connection should succeed.

\# Vidar is READY TO GO

\# Logout as vidar, login as root

\# Source the environment
SHOW_ENV="Y"
. /home/vidar/dev/etc/vidar_env.sh

cd ../scripts

./vidar_start_postgres.sh

\# ... Vidar starts here ...

\# Should succeed. if not diagnose why.
\# OOB login may be needed :-(

\# -----  Testing with test input  ------

\# As root or install user

cd /home/vidar/dev/utils

sudo /bin/sh push.sh 0.05   # or just push.sh 0.05,  use 0.1 if needed

\# Then tail -f /home/vidar/dev/logs/readSEC_stderr.txt
\# or /home/vidar/dev/logs/add2BAD_stderr.txt

\# In another session as root:

ipfw table BAD list

\# and

ipfw table BAD list | wc

\# Then

sudo -u vidar psql -U vidar -d vidar -c "select count(*) from offenders;"

\# Watch IPFW table BAD fill count and postgresql offenders table fill count.
\# These two lines have to be executed close in time (use up arrow to replay)
\#  sudo -u vidar psql -U vidar -d vidar -c "select count(*) from offenders;"
\#  count 
\# -------
\#    947
\# (1 row)
\# 
\# ipfw table BAD list | wc
\#      947    1894   18793
\# 
\# 
\# 
\# Try some queries from PostgreSQL

\# Get count of permanent_block entries
\# Should be at least one, but more will show eventually
sudo -u vidar psql -U vidar -d vidar -c "select count(*) from offenders where permanent_block = 1;"  

\# Get list of offenders targeted for removal at listed time
sudo -u vidar psql -U vidar -d vidar -c "select offender_ip, context, desc_line, remove_after from offenders order by context, desc_line asc;"


\# Same thing ordered by remove_after ascending (closest to removal first)
sudo -u vidar psql -U vidar -d vidar -c "select offender_ip, context, desc_line, remove_after from offenders order by remove_after asc;"

\# Get list of offenders with the most serious offenses in descending order.  This is determined by block_seconds.
sudo -u vidar psql -U vidar -d vidar -c "select offender_ip, context, desc_line, block_seconds  from offenders order by block_seconds desc;"


There are some debugging statements that write to STDERR in both ~/src/vidar/scripts/readSEC.pl and ~src/vidar/scripts/add2BAD.pl.
These can be commented out or the STDERR streams can be redirected to regular files or to /dev/null.
See the the *~/src/vidar/etc/vidar_env.sh* script for all important environment definitions.

\# TESTING

To test, change the link in ~src/vidar/etc/vidar_env.sh  to point to vidar_dev.sh
and comment the following lines (production use):

- AUTHLOG=/var/log/auth.log
- EMAILLOG=/var/log/maillog
- NGINXLOG=/var/log/nginx/access.log

Then uncomment out these lines to use the included test data:

- AUTHLOG=${VIDAR_INPUT}/auth.log
- EMAILLOG=${VIDAR_INPUT}/maillog
- NGINXLOG=${VIDAR_INPUT}/access.log

Start up Vidar with:
  ~/src/vidar/postgres/vidar_start_postgres.sh

Then run
  /bin/sh ~/src/vidar/utils/push.sh .1

This sends 10 lines per second through the Vidar system.
Navigate to the logs directory (~/src/vidar/logs) and watch the files:

- tail -f readSEC_stderr.txt
- tail -f add2BAD_stderr.txt
 
And check the IPFW firewall

- As root, ipfw table BAD list  (or ipfw table BAD list | wc)


## Feedback Welcome!

Drop me a line at jpb AT jimby.name.

