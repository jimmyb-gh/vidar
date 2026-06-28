
--- Use this script from user vidar, not from user postgres!
--- Example:
---   psql -d vidar -f /usr/local/vidar/postgres/_vidar.sql


DROP TABLE IF EXISTS public.offenders;

\c vidar

SET ROLE vidar;


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
