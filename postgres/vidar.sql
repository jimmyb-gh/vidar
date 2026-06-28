
\set ON_ERROR_STOP on

--- This is the master script for setting vidar roles, auths, and tables.
--- It combines _vidar_auth.sql and _vidar.sql into this one script.
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
    context           text NOT NULL CHECK (length(context) <= 20),
    rule_num          integer NOT NULL,
    permanent_block   integer NOT NULL DEFAULT 0 CHECK (permanent_block IN (0, 1)),
    block_seconds     integer NOT NULL,
    active_block      integer NOT NULL DEFAULT 1 CHECK (active_block in (0,1)),
    remove_after      timestamp without time zone DEFAULT (now() + interval '24 hours') NOT NULL,
    ipfw_removed_at   timestamp without time zone DEFAULT NULL,
    repeat_count      integer DEFAULT 1 NOT NULL,
    evidence          text NOT NULL,

    CONSTRAINT offenders_active_removed_check
    CHECK (
          NOT (active_block = 1 AND ipfw_removed_at IS NOT NULL)
    ) 
);

--- Not needed: ALTER TABLE public.offenders OWNER TO vidar;

CREATE INDEX idx_offenders_time ON public.offenders (offense_time);
--- 
--- Not needed because of UNIQUE attribute on column
--- CREATE INDEX idx_offenders_ip ON public.offenders (offender_ip);
---
CREATE INDEX idx_offenders_entry ON public.offenders (entry);
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
    '2025-10-19 04:00:00',
    '2001:db8:9999:9999:9999:9999:9999:9999',
    'desc line',
    'entry line',
    'context value',
    99999,
    1,
    0,
    1,
    'infinity',
    NULL,
    'evidence text evidence text'
);
