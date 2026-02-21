# vidar
VIDAR - Server Protection

Vidar is a combination of programs, a PostgreSQL database, and the SEC
correlator that reads logfiles from authentication, email (postfix),
and web server (nginx), and takes action based on SEC rules to add rules
to an IPFW firewall.  In concept it is similar to blacklistd.

SEC reads the logs in real time and based on its rules, outputs
metadata that is piped to a process that inserts the events into
and PostgreSQL data and further pipes the offending IP address
to a script that updates a table named "BAD" in IPFW.  This table
is read by IPFW rules to block offending external systems from
wrecking havoc on a FreeBSD host.

A corresponding table named GOOD contains whitelisted IP addresses
so you don't accidently lock yourself out.

<RANT>
Are you sick and tired of seeing:
"2a03:b0c0:3:d0::402:d001 - - [31/Jan/2026:17:37:17 -0500] \x16\x03\x01\x05\xDE\x01 ..."
in your nginx logs and sick of seeing:
"Feb 20 16:36:03 jimby dovecot[59472]: imap-login: Disconnected: Connection closed (no auth attempts in 5 secs): user=<>, rip=206.168.34.125, lip=174.136.97.66, TLS: Connection closed, ..."
in your mail logs and sick of seeing:
"Feb 20 12:47:58 jimby sshd-session[47730]: Invalid user zzzz from 2607:f170:44:12::5d0 port 520"
in your authentication logs?

With Vidar, you get to put the hammer down:

  "If you abuse my system, I shut you out. Permanently."

</RANT>

And with additional trick - a way to dump the IPFW BAD table and a way
to import it later - you can keep this database of shame up to date on
all those miscreants and keep them away.





