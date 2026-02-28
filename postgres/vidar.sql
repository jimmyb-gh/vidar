--
-- PostgreSQL database dump
--


-- Dumped from database version 17.7
-- Dumped by pg_dump version 17.7

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ipfw_queue; Type: TABLE; Schema: public; Owner: jpb
--

CREATE TABLE public.ipfw_queue (
    id integer NOT NULL,
    ip_addr inet NOT NULL,
    added_at timestamp without time zone DEFAULT now() NOT NULL,
    remove_after timestamp without time zone DEFAULT (now() + '24:00:00'::interval) NOT NULL
);


ALTER TABLE public.ipfw_queue OWNER TO jpb;

--
-- Name: ipfw_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: jpb
--

CREATE SEQUENCE public.ipfw_queue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ipfw_queue_id_seq OWNER TO jpb;

--
-- Name: ipfw_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jpb
--

ALTER SEQUENCE public.ipfw_queue_id_seq OWNED BY public.ipfw_queue.id;


--
-- Name: offenders; Type: TABLE; Schema: public; Owner: jpb
--

CREATE TABLE public.offenders (
    id integer NOT NULL,
    offense_time timestamp without time zone DEFAULT now() NOT NULL,
    offender_ip inet NOT NULL,
    desc_line text NOT NULL,
    entry text NOT NULL,
    context text NOT NULL,
    rule_num integer NOT NULL,
    repeats integer NOT NULL DEFAULT 1,
    evidence text NOT NULL,
    CONSTRAINT offenders_context_check CHECK ((length(context) <= 20))
);


ALTER TABLE public.offenders OWNER TO jpb;

--
-- Name: offenders_id_seq; Type: SEQUENCE; Schema: public; Owner: jpb
--

CREATE SEQUENCE public.offenders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offenders_id_seq OWNER TO jpb;

--
-- Name: offenders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jpb
--

ALTER SEQUENCE public.offenders_id_seq OWNED BY public.offenders.id;


--
-- Name: ipfw_queue id; Type: DEFAULT; Schema: public; Owner: jpb
--

ALTER TABLE ONLY public.ipfw_queue ALTER COLUMN id SET DEFAULT nextval('public.ipfw_queue_id_seq'::regclass);


--
-- Name: offenders id; Type: DEFAULT; Schema: public; Owner: jpb
--

ALTER TABLE ONLY public.offenders ALTER COLUMN id SET DEFAULT nextval('public.offenders_id_seq'::regclass);


--
-- Name: ipfw_queue ipfw_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: jpb
--

ALTER TABLE ONLY public.ipfw_queue
    ADD CONSTRAINT ipfw_queue_pkey PRIMARY KEY (id);


--
-- Name: offenders offenders_pkey; Type: CONSTRAINT; Schema: public; Owner: jpb
--

ALTER TABLE ONLY public.offenders
    ADD CONSTRAINT offenders_pkey PRIMARY KEY (id);


--
-- Name: idx_offenders_context; Type: INDEX; Schema: public; Owner: jpb
--

CREATE INDEX idx_offenders_context ON public.offenders USING btree (context);


--
-- Name: idx_offenders_entry; Type: INDEX; Schema: public; Owner: jpb
--

CREATE INDEX idx_offenders_entry ON public.offenders USING btree (entry);


--
-- Name: idx_offenders_ip; Type: INDEX; Schema: public; Owner: jpb
--

CREATE INDEX idx_offenders_ip ON public.offenders USING btree (offender_ip);


--
-- Name: idx_offenders_rule; Type: INDEX; Schema: public; Owner: jpb
--

CREATE INDEX idx_offenders_rule ON public.offenders USING btree (rule_num);


--
-- Name: idx_offenders_repeats; Type: INDEX; Schema: public; Owner: jpb
--

CREATE INDEX idx_offenders_repeats ON public.offenders USING btree (repeats);


--
-- Name: idx_offenders_time; Type: INDEX; Schema: public; Owner: jpb
--

CREATE INDEX idx_offenders_time ON public.offenders USING btree (offense_time);


--
-- PostgreSQL database dump complete
--


