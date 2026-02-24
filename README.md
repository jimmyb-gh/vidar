# VIDAR - Server Protection for Internet facing FreeBSD Servers.

Vidar is a combination of programs, a PostgreSQL database, and the SEC
correlator engine that reads logfiles from authentication, email (postfix),
and web server (nginx), and takes action based on SEC rules to add entries
to an IPFW firewall.  In concept it is similar to fail2ban.

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

  "If you abuse my system, I shut you out. Permanently."

\</RANT>

And with an additional trick - a way to dump the IPFW BAD table and a way
to import it later - you can keep this database of shame up to date on
all those miscreants and keep them away.  You can even import the BAD table
on another FreeBSD system running IPFW.


## Implementation Notes

This is a collection of shell and perl scripts.  It is fairly robust.
The code has been tested on a Lenovo T530 (16G RAM) with the utilities
in the /root/src/vidar/utils directory.  The code was able to keep up
with 3 different input streams (auth.log, nginx/access.log, and maillog)
at about 900 to 1000 messages per second.

As written, all the code lives in /root/src/vidar.  

You will need 

- postgresql17-client-17.7_2     PostgreSQL database (client)
- postgresql17-server-17.7_1     PostgreSQL is the most advanced open-source database available anywhere
- sec-2.9.3                      Simple event (logs) correlator
- perl5-5.42.0_1                 Practical Extraction and Report Language

Install PostgreSQL create a user with administrator privileges.

Have that user create the database "vidar" using the sql script in 
postgres/vidar.sql.

Install SEC.  The rules for postfix, nginx, and FreeBSD authentication are
already installed, but can be added to at your discretion.

The file *scripts/vidar_start_postgres.sh* starts everything up.  There are some
pauses in the scripts to let things (i.e. IPFW) settle.  The script uses daemon(8)
so it is unlikely you will get locked out.

There are some debugging statements that write to STDERR in both scripts/readSEC.pl and scripts/add2BAD.pl.
These can be commented out or the STDERR streams can be redirected to regular files or to /dev/null.
See the the *src/vidar/vidar_env.sh* script for all important definitions.

In theory, you should be able to, as root:
- \# pkg install postgresql17-client postgresql17-server sec perl5 p5-DBD-Pg p5-DBI
- \# # Set up and initialize postgresql17, ensuring you have admin access 
- \# mkdir /root/src && cd /root/src
- \# git clone https://github.com/jimmyb-gh/vidar
- \# # Edit the file /root/src/vidar/scripts/ipfw_good_table.sh and enter your own IP addresses (v4 and v6).
- \# # Install the VIDAR database schema in /root/src/vidar/postgres/vidar.sql
- \# # Edit any variables desired in /root/src/vidar/vidar_env.sh
- \# # Light 'er up!
- \# cd /root/src/vidar/scripts/
- \# ./vidar_start_postgres.sh

This runs the code for sec(1) and the vidar_readSEC.pl and vidar_add2BAD.pl.
If you have set up the debug output (see the section on debugging in vidar_env.sh)
you should be able to see the stderr output of the vidar_readSEC.pl and vidar_add2BAD.pl
scripts in real time.  

To test, edit vidar_env.sh and navigate to the line 
\# TESTING

and comment the following lines (production use):
AUTHLOG=/var/log/auth.log
EMAILLOG=/var/log/maillog
NGINXLOG=/var/log/nginx/access.log

Then uncomment out these lines 
AUTHLOG=${VIDAR_INPUT}/auth.log
EMAILLOG=${VIDAR_INPUT}/maillog
NGINXLOG=${VIDAR_INPUT}/access.log

Start up Vidar with:
  scripts/vidar_start_postgres.sh

Then run
  /bin/sh utils/push.sh .1

This sends 10 lines per second through the Vidar protection system.
Navigate to the logs directory and watch the files:

  tail -f readSEC_stderr.txt
  tail -f add2BAD_stderr.txt



 

## Feedback Welcome!

Drop me a line at jpb AT jimby.name.


