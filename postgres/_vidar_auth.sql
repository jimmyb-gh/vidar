
\set ON_ERROR_STOP on

--- Use this script from user postgres, not from user vidar!
--- Example:
---   psql -U postgres -d postgres -f /usr/local/vidar/postgres/_vidar_auth.sql

DROP DATABASE IF EXISTS vidar;
DROP ROLE IF EXISTS vidar;

CREATE ROLE vidar LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;

CREATE DATABASE vidar OWNER vidar;

\connect vidar


REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE vidar FROM PUBLIC;

GRANT CONNECT ON DATABASE vidar TO vidar;
GRANT USAGE, CREATE ON SCHEMA public TO vidar;

ALTER SCHEMA public OWNER TO vidar;

