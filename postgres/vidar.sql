
\set ON_ERROR_STOP on

--- This is the master script for setting Vidar database roles, auths, and tables.
---
--- After reinitializing postgresql this is the only script you need to run.
---
--- Note, you also need to set up peer authentication in pg_hba.conf
---
---  ...
--- # TYPE  DATABASE        USER            ADDRESS                 METHOD
--- 
--- # jpb modifications for vidar
--- local	vidar		vidar					peer
--- 
---  ... rest of file is unchanged.
---
--- After making the above change, you MUST reload postgresql:
---
---    service postgresql restart
---
--- Use this script from user postgres, not from user vidar!
--- Example:
---   psql -U postgres -d postgres -f /usr/local/vidar/postgres/vidar.sql
---
--- NOTE: THIS SCRIPT DROPS THE Vidar DATABASE AND vidar ROLE IMMEDIATELY!!
---       ALL DATA WILL BE REMOVED.  BACKUP YOUR DATABASE IF THIS IS A CONCERN.

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


--- Set role to vidar for all table creation stuff.

SET ROLE vidar;


DROP TABLE IF EXISTS public.offenders;

CREATE TABLE public.offenders (
    id                serial PRIMARY KEY,
    offense_time      timestamp without time zone DEFAULT now() NOT NULL,
    offender_ip       inet NOT NULL UNIQUE,
    desc_line         text NOT NULL,
    entry             text NOT NULL,
    context           text NOT NULL CHECK (length(context) <= 30),
    rule_num          integer NOT NULL CHECK (rule_num > 0),
    permanent_block   integer NOT NULL DEFAULT 0 CHECK (permanent_block IN (0, 1)),
    block_seconds     integer NOT NULL CHECK (block_seconds >= 0),
    active_block      integer NOT NULL DEFAULT 1 CHECK (active_block in (0,1)),
    remove_after      timestamp without time zone DEFAULT (now() + interval '24 hours') NOT NULL,
    ipfw_removed_at   timestamp without time zone DEFAULT NULL,
    repeat_count      integer NOT NULL DEFAULT 1 CHECK (repeat_count >= 1),
    evidence          text NOT NULL,

    CONSTRAINT offenders_active_removed_check
    CHECK (
          (active_block = 1 AND ipfw_removed_at IS NULL)
       OR
          (active_block = 0 AND ipfw_removed_at IS NOT NULL)
    ) 
);

--- Not needed: ALTER TABLE public.offenders OWNER TO vidar;

CREATE INDEX idx_offenders_time ON public.offenders (offense_time);
--- 
--- Not needed because of UNIQUE attribute on column
--- CREATE INDEX idx_offenders_ip ON public.offenders (offender_ip);
---
--- Not useful for a text field.  Do not index full raw log text.
--- CREATE INDEX idx_offenders_entry ON public.offenders (entry);
CREATE INDEX idx_offenders_context ON public.offenders (context);
CREATE INDEX idx_offenders_rule ON public.offenders (rule_num);
CREATE INDEX idx_offenders_permanent_block ON public.offenders (permanent_block);
CREATE INDEX idx_offenders_active_block ON public.offenders (active_block);
CREATE INDEX idx_offenders_ipfw_removed_at ON public.offenders (ipfw_removed_at);

---
--- Partial index: only rows matching the WHERE clause are included in the index.
---
CREATE INDEX idx_offenders_remove_after_active  ON public.offenders (remove_after)
       WHERE permanent_block = 0
         AND active_block = 1
         AND ipfw_removed_at IS NULL;
---
--- Add an initial dummy record.
---
INSERT INTO public.offenders (
    offense_time,
    offender_ip,
    desc_line,
    entry,
    context,
    rule_num,
    permanent_block,
    block_seconds,
    active_block,
    remove_after,
    ipfw_removed_at,
    evidence
)
VALUES (
    '2025-01-01 01:00:00',
    '2001:db8:9999:9999:9999:9999:9999:9999',
    'dummy record desc line',
    'dummy record entry line',
    'dummy record context value',
    99999,
    1,
    0,
    1,
    'infinity',
    NULL,
    'dummy record evidence text inserted by vidar.sql'
);

---
--- Create new blocking_config table to keep the blocking values.
--- See ChatGPT discussion on charging repeat offenders more.
---
--- We calculate a block_seconds value based on the repeat count:
--- block_seconds(r)=(B*(10/(10-r)))^p  where
--- 
---   r  is the repeat count
---   B  is the original block duration (7200 seconds, etc.)
---   p  is the exponent controlling the penalty acceleration
--- 
--- See www.desmos.com/calculator for testing values of r, B, and p.
--- 
---    for example  y = 1((10/10-x))^2
--- 
--- The penalties for repeat offenders becomes:
--- 
--- | repeats (x) |        multiplier (y) |                   approx |
--- | ----------: | --------------------: | -----------------------: |
--- |           0 |         ( (10/10)^2 ) |                  1.0000× |
--- |           1 | ( (10/9)^2 = 100/81 ) |                  1.2346× |
--- |           2 |  ( (10/8)^2 = 25/16 ) |                  1.5625× |
--- |           3 | ( (10/7)^2 = 100/49 ) |                  2.0408× |
--- |           4 |   ( (10/6)^2 = 25/9 ) |                  2.7778× |
--- |           5 |          ( (10/5)^2 ) |                  4.0000× |
--- |           6 |          ( (10/4)^2 ) |                  6.2500× |
--- |           7 |          ( (10/3)^2 ) |                 11.1111× |
--- |           8 |          ( (10/2)^2 ) |                 25.0000× |
--- |           9 |          ( (10/1)^2 ) |                100.0000× |
--- |          10 |           divide by 0 | **infinity / permanent** |
--- 
--- so for a 1 day block (86400 seconds), the values become:
--- 
--- repeat 0      1 day
--- repeat 1      1.15 days
--- repeat 3      1.56 days
--- repeat 5      2.25 days
--- repeat 7      3.5 days
--- repeat 10     9 days
--- repeat 12     25 days
--- repeat 13     56 days
--- repeat 14     225 days
--- repeat 15     permanent
---
--- All we need is a table to maintain the values for the repeat asymptote (10 above),
--- the repeat exponent (2 above), and a permanent block cutoff value.  This last value
--- is a shortcut to getting to permanent block status - 8 or 9 repeats for example.
---
--- 
--- Table is in hash format.  The SQL functions select a value into variables where
--- key equals the supplied text.

CREATE TABLE blocking_config (
  key    text  PRIMARY KEY,
  value  numeric NOT NULL
);

INSERT INTO blocking_config VALUES
  ('repeat_asymptote', 10),
  ('repeat_exponent',   2),
  ('blocking_cutoff',  10)
;



CREATE OR REPLACE FUNCTION vidar_blocking_multiplier(repeats integer)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE
    asymptote numeric;
    exponent  numeric;
BEGIN
    SELECT value INTO asymptote
      FROM blocking_config
     WHERE key = 'repeat_asymptote';

    SELECT value INTO exponent
      FROM blocking_config
     WHERE key = 'repeat_exponent';

    IF repeats >= asymptote THEN
        RETURN NULL;
    END IF;

    RETURN power(
        asymptote / (asymptote - repeats),
        exponent
    );
END;
$$;
