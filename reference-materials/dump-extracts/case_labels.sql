--
-- PostgreSQL database dump
--

\restrict IGHdgNddtDmsrS4p7zufAoyXbg5CbqqrJhcOqrweQaG3a3tx208ITtthq5JG6OA

-- Dumped from database version 18.3 (Homebrew)
-- Dumped by pg_dump version 18.3 (Homebrew)

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

--
-- Data for Name: case_alert_mapping; Type: TABLE DATA; Schema: efrm; Owner: -
--

COPY efrm.case_alert_mapping (id, case_id, alert_id, alert_type, alert_source_table, alert_score, normalized_score, is_primary_flag, created_at, status, disposition_code, disposition_details, decision_code, decision_payload, decision_remarks, decision_submitted_by, decision_submitted_at) FROM stdin;
1	1	118	SCREENING	screening_alert	1000	1.0000	N	2026-06-23 09:30:10	OPEN	\N	\N	\N	\N	\N	\N	\N
2	1	119	SCREENING	screening_alert	1000	1.0000	N	2026-06-23 09:30:11	OPEN	\N	\N	\N	\N	\N	\N	\N
3	1	120	SCREENING	screening_alert	1000	1.0000	Y	2026-06-23 09:30:12	OPEN	\N	\N	\N	\N	\N	\N	\N
4	1	121	SCREENING	screening_alert	1000	1.0000	N	2026-06-23 09:30:13	OPEN	\N	\N	\N	\N	\N	\N	\N
5	2	57	DEVICE	device_alert	102	0.1020	Y	2026-06-23 09:40:10	OPEN	\N	\N	\N	\N	\N	\N	\N
6	2	58	DEVICE	device_alert	102	0.1020	N	2026-06-23 09:40:11	OPEN	\N	\N	\N	\N	\N	\N	\N
7	3	61	DEVICE	device_alert	77	0.0770	Y	2026-06-23 09:50:10	OPEN	\N	\N	\N	\N	\N	\N	\N
9	4	56	ADVERSE_MEDIA	adverse_alert	100	0.1000	N	2026-06-29 09:40:00	OPEN	\N	\N	\N	\N	\N	\N	\N
10	4	1	TRANSACTION	transaction_alert	165	0.1650	N	2026-06-29 09:40:00	OPEN	\N	\N	\N	\N	\N	\N	\N
11	4	63	DEVICE	device_alert	185	0.1850	N	2026-06-29 09:40:00	OPEN	\N	\N	\N	\N	\N	\N	\N
12	5	2	TRANSACTION	transaction_alert	187	0.1870	Y	2026-06-29 09:45:00	OPEN	\N	\N	\N	\N	\N	\N	\N
13	5	64	DEVICE	device_alert	150	0.1500	N	2026-06-29 09:45:00	OPEN	\N	\N	\N	\N	\N	\N	\N
14	6	123	SCREENING	screening_alert	810	0.8100	Y	2026-06-29 08:45:00	OPEN	\N	\N	\N	\N	\N	\N	\N
15	7	124	SCREENING	screening_alert	1000	1.0000	Y	2026-06-29 08:20:00	OPEN	\N	\N	\N	\N	\N	\N	\N
16	7	57	ADVERSE_MEDIA	adverse_alert	100	0.1000	N	2026-06-29 08:20:00	OPEN	\N	\N	\N	\N	\N	\N	\N
17	8	65	DEVICE	device_alert	150	0.1500	Y	2026-06-29 10:20:00	OPEN	\N	\N	\N	\N	\N	\N	\N
118	42	110	DEVICE	device_alert	162	0.1620	Y	2026-06-30 09:44:00	OPEN	\N	\N	\N	\N	\N	\N	\N
119	42	42	TRANSACTION	transaction_alert	181	0.1810	Y	2026-06-30 09:48:00	OPEN	\N	\N	\N	\N	\N	\N	\N
120	42	111	DEVICE	device_alert	148	0.1480	N	2026-06-30 09:52:00	OPEN	\N	\N	\N	\N	\N	\N	\N
121	42	43	TRANSACTION	transaction_alert	164	0.1640	N	2026-06-30 09:55:00	OPEN	\N	\N	\N	\N	\N	\N	\N
122	43	112	DEVICE	device_alert	170	0.1700	Y	2026-06-30 10:07:00	OPEN	\N	\N	\N	\N	\N	\N	\N
123	43	113	DEVICE	device_alert	145	0.1450	N	2026-06-30 10:15:00	OPEN	\N	\N	\N	\N	\N	\N	\N
125	45	44	TRANSACTION	transaction_alert	122	0.1220	Y	2026-07-02 07:13:12.388842	OPEN	\N	\N	\N	\N	\N	\N	\N
126	46	150	SCREENING	screening_alert	790	0.7900	Y	2026-07-02 13:34:56.163889	OPEN	\N	\N	\N	\N	\N	\N	\N
127	47	84	SCREENING	adverse_alert	88	0.0880	Y	2026-07-04 07:46:38.407174	OPEN	\N	\N	\N	\N	\N	\N	\N
128	48	56	TRANSACTION	transaction_alert	785	0.7850	Y	2026-07-04 07:47:54.49518	OPEN	\N	\N	\N	\N	\N	\N	\N
129	48	157	SCREENING	screening_alert	960	0.9600	Y	2026-07-04 20:33:30.531092	OPEN	\N	\N	\N	\N	\N	\N	\N
131	49	160	SCREENING	screening_alert	1000	1.0000	Y	2026-07-08 14:39:19.44696	OPEN	\N	\N	\N	\N	\N	\N	\N
132	50	161	SCREENING	screening_alert	1000	1.0000	Y	2026-07-08 17:01:21.52049	OPEN	\N	\N	\N	\N	\N	\N	\N
133	3	62	DEVICE	device_alert	77	0.0770	N	2026-07-09 07:42:15.179619	OPEN	\N	\N	\N	\N	\N	\N	\N
134	2	114	DEVICE	device_alert	102	0.1020	N	2026-07-09 10:23:28.023795	OPEN	\N	\N	\N	\N	\N	\N	\N
135	2	115	DEVICE	device_alert	102	0.1020	N	2026-07-09 17:09:06.362518	OPEN	\N	\N	\N	\N	\N	\N	\N
124	44	151	SCREENING	screening_alert	780	0.7800	Y	2026-06-30 07:56:00	CLOSED	FALSE_POSITIVE	test	FALSE_POSITIVE	{}	test	analyst1	2026-07-09 17:11:11.926825
130	44	159	SCREENING	screening_alert	430	0.4300	N	2026-07-04 20:36:01.091057	CLOSED	FALSE_POSITIVE	test	FALSE_POSITIVE	{}	test	analyst1	2026-07-09 17:11:11.926825
116	41	109	DEVICE	device_alert	168	0.1680	N	2026-06-30 09:38:00	CLOSED	CONFIRMED_FRAUD	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	CONFIRMED_FRAUD	\N	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	\N	\N
8	4	122	SCREENING	screening_alert	930	0.9300	Y	2026-06-29 09:40:00	CLOSED	ATTEMPTED_FRAUD	test	ATTEMPTED_FRAUD	{}	test	admin	2026-07-10 15:01:48.779576
137	52	162	SCREENING	screening_alert	1000	1.0000	Y	2026-07-14 08:20:00.043937	OPEN	\N	\N	\N	\N	\N	\N	\N
138	53	163	SCREENING	screening_alert	1000	1.0000	Y	2026-07-14 08:50:03.679817	OPEN	\N	\N	\N	\N	\N	\N	\N
139	53	92	SCREENING	adverse_alert	100	0.1000	N	2026-07-14 08:52:18.622275	OPEN	\N	\N	\N	\N	\N	\N	\N
112	41	149	SCREENING	screening_alert	910	0.9100	Y	2026-06-30 09:06:00	CLOSED	CONFIRMED_FRAUD	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	CONFIRMED_FRAUD	\N	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	\N	\N
113	41	82	ADVERSE_MEDIA	adverse_alert	96	0.0960	N	2026-06-30 09:10:00	CLOSED	CONFIRMED_FRAUD	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	CONFIRMED_FRAUD	\N	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	\N	\N
114	41	108	DEVICE	device_alert	190	0.1900	N	2026-06-30 09:25:00	CLOSED	CONFIRMED_FRAUD	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	CONFIRMED_FRAUD	\N	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	\N	\N
115	41	40	TRANSACTION	transaction_alert	188	0.1880	N	2026-06-30 09:32:00	CLOSED	CONFIRMED_FRAUD	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	CONFIRMED_FRAUD	\N	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	\N	\N
117	41	41	TRANSACTION	transaction_alert	176	0.1760	N	2026-06-30 09:38:00	CLOSED	CONFIRMED_FRAUD	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	CONFIRMED_FRAUD	\N	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	\N	\N
136	51	55	TRANSACTION	transaction_alert	910	0.9100	Y	2026-07-09 17:14:16.940437	CLOSED	CONFIRMED_FRAUD	fwefw	CONFIRMED_FRAUD	\N	fwefw	\N	\N
\.


--
-- Data for Name: case_decision_master; Type: TABLE DATA; Schema: efrm; Owner: -
--

COPY efrm.case_decision_master (decision_id, decision_code, decision_name, alert_type, service_code, entity_type, requires_loss_amount, requires_recovery, requires_remarks, requires_evidence, requires_approval, display_order, is_active, created_at, updated_at, config_master_id, updates_customer_risk, risk_event_score) FROM stdin;
1	CONFIRMED_FRAUD	Confirmed Fraud	ANY	ANY	ANY	Y	Y	Y	N	N	10	Y	2026-07-01 22:35:57.216568	2026-07-02 19:06:32.271329	1	Y	900
12	ATTEMPTED_FRAUD	Attempted Fraud - Prevented	ANY	ANY	ANY	N	N	Y	N	N	20	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	Y	650
13	UPI_FRAUD_CONFIRMED	UPI Fraud Confirmed	TRANSACTION	UPI	ANY	Y	Y	Y	N	N	30	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	Y	900
14	ACCOUNT_TAKEOVER_SUSPECTED	Account Takeover Suspected	DEVICE	MOBILE_APP	ANY	N	N	Y	Y	Y	40	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	N	0
15	DEVICE_COMPROMISED	Device Compromised	DEVICE	MOBILE_APP	ANY	N	N	Y	N	N	50	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	N	0
4	REVERSE_TRANSACTION	Reverse Transaction	TRANSACTION	ANY	ANY	Y	Y	Y	N	Y	60	Y	2026-07-01 22:35:57.216568	2026-07-02 19:06:32.271329	1	N	0
17	MONEY_MULE_SUSPECTED	Money Mule Suspected	TRANSACTION	ANY	ANY	N	N	Y	Y	Y	70	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	Y	850
19	EDD_COMPLETED	EDD Completed	SCREENING	KYC	ANY	N	N	Y	Y	N	80	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	N	0
22	CONTINUE_ONBOARDING	Continue Onboarding	SCREENING	ONBOARDING	ANY	N	N	Y	N	N	110	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	N	0
2	FALSE_POSITIVE	False Positive	ANY	ANY	ANY	N	N	Y	N	N	90	Y	2026-07-01 22:35:57.216568	2026-07-04 12:03:55.809277	1	Y	0
3	GENUINE	Genuine Customer Activity	ANY	ANY	ANY	N	N	Y	N	N	100	Y	2026-07-01 22:35:57.216568	2026-07-04 12:03:55.809277	1	Y	0
23	REJECT_ONBOARDING	Reject Onboarding	SCREENING	ONBOARDING	ANY	N	N	Y	Y	Y	120	Y	2026-07-02 01:54:43.847145	2026-07-02 19:06:32.271329	1	N	0
61	SANCTIONS_FALSE_MATCH	Sanctions - False Match	SCREENING	SCREENING	ANY	N	N	Y	N	N	200	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
62	SANCTIONS_POTENTIAL_MATCH	Sanctions - Potential Match	SCREENING	SCREENING	ANY	N	N	Y	Y	Y	210	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	N	0
63	SANCTIONS_TRUE_MATCH	Sanctions - Confirmed Match	SCREENING	SCREENING	ANY	N	N	Y	Y	Y	220	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	950
64	PEP_CONFIRMED	Politically Exposed Person Confirmed	SCREENING	SCREENING	ANY	N	N	Y	Y	N	230	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	600
65	PEP_NOT_CONFIRMED	Politically Exposed Person Not Confirmed	SCREENING	SCREENING	ANY	N	N	Y	N	N	240	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
66	SCREENING_INCONCLUSIVE	Screening Review Inconclusive	SCREENING	SCREENING	ANY	N	N	Y	Y	N	250	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	N	0
67	SCREENING_DUPLICATE	Duplicate Screening Alert	SCREENING	SCREENING	ANY	N	N	Y	N	N	260	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	N	0
68	ADVERSE_DIFFERENT_SUBJECT	Adverse Media - Different Subject	SCREENING	ADVERSE_MEDIA	ANY	N	N	Y	N	N	300	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
69	ADVERSE_SOURCE_NOT_CREDIBLE	Adverse Media - Source Not Credible	SCREENING	ADVERSE_MEDIA	ANY	N	N	Y	Y	N	310	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	N	0
70	ADVERSE_NOT_MATERIAL	Adverse Media - Not Material	SCREENING	ADVERSE_MEDIA	ANY	N	N	Y	N	N	320	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
71	ADVERSE_MATERIAL	Adverse Media - Material Risk Identified	SCREENING	ADVERSE_MEDIA	ANY	N	N	Y	Y	Y	330	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	700
72	ADVERSE_INCONCLUSIVE	Adverse Media Review Inconclusive	SCREENING	ADVERSE_MEDIA	ANY	N	N	Y	Y	N	340	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	N	0
73	ADVERSE_LEGAL_ACTION_CONFIRMED	Adverse Media - Legal Action Confirmed	SCREENING	ADVERSE_MEDIA	ANY	N	N	Y	Y	Y	350	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	850
74	TXN_AUTHORIZED_GENUINE	Authorized Genuine Transaction	TRANSACTION	TRANSACTION	ANY	N	N	Y	N	N	400	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
75	TXN_FRAUD_CONFIRMED	Transaction Fraud Confirmed	TRANSACTION	TRANSACTION	ANY	Y	Y	Y	Y	Y	410	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	950
76	TXN_FRAUD_ATTEMPT_PREVENTED	Fraud Attempt Prevented	TRANSACTION	TRANSACTION	ANY	N	N	Y	N	N	420	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	700
77	TXN_ACCOUNT_TAKEOVER_CONFIRMED	Account Takeover Confirmed	TRANSACTION	TRANSACTION	ANY	N	N	Y	Y	Y	430	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	900
78	TXN_MONEY_MULE_SUSPECTED	Money Mule Activity Suspected	TRANSACTION	TRANSACTION	ANY	N	N	Y	Y	Y	440	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	800
79	TXN_MONEY_MULE_CONFIRMED	Money Mule Activity Confirmed	TRANSACTION	TRANSACTION	ANY	N	N	Y	Y	Y	450	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	950
80	TXN_SCAM_CONFIRMED	Customer Scam Confirmed	TRANSACTION	TRANSACTION	ANY	Y	Y	Y	Y	Y	460	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	900
81	TXN_SUSPICIOUS_ACTIVITY_CONFIRMED	Suspicious Transaction Activity Confirmed	TRANSACTION	TRANSACTION	ANY	N	N	Y	Y	Y	470	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	800
82	TXN_TECHNICAL_ANOMALY	Transaction Processing Anomaly	TRANSACTION	TRANSACTION	ANY	N	N	Y	Y	N	480	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	N	0
83	DEVICE_TRUSTED	Trusted Device Confirmed	DEVICE	DEVICE	ANY	N	N	Y	N	N	500	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
84	DEVICE_SHARED_LEGITIMATE	Legitimate Shared Device	DEVICE	DEVICE	ANY	N	N	Y	Y	N	510	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	100
85	DEVICE_RISK_ANOMALY	Device Risk Anomaly	DEVICE	DEVICE	ANY	N	N	Y	Y	N	520	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	550
86	DEVICE_COMPROMISE_CONFIRMED	Compromised Device Confirmed	DEVICE	DEVICE	ANY	N	N	Y	Y	Y	530	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	850
87	DEVICE_STOLEN_REPORTED	Stolen Device Reported	DEVICE	DEVICE	ANY	N	N	Y	Y	Y	540	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	800
88	DEVICE_ROOTED_OR_EMULATED	Rooted or Emulated Device Confirmed	DEVICE	DEVICE	ANY	N	N	Y	Y	N	550	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	650
89	DEVICE_BOT_ACTIVITY_CONFIRMED	Automated Bot Activity Confirmed	DEVICE	DEVICE	ANY	N	N	Y	Y	Y	560	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	850
90	DEVICE_FALSE_POSITIVE	Device Alert - False Positive	DEVICE	DEVICE	ANY	N	N	Y	N	N	570	Y	2026-07-24 03:52:19.381156	2026-07-24 03:52:19.381156	1	Y	0
\.


--
-- Data for Name: case_events; Type: TABLE DATA; Schema: efrm; Owner: -
--

COPY efrm.case_events (event_id, case_id, event_type, event_description, actor_id, payload, created_at) FROM stdin;
1	1	CASE_CREATED	Case created from four screening alerts	rule_engine	{"priority": "P1", "final_score": 960, "alerts_added": [118, 119, 120, 121]}	2026-06-23 09:30:15
2	1	CASE_ASSIGNED	Case 1 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "Initial screening case pickup"}	2026-06-23 09:35:00
3	2	CASE_CREATED	Case created from repeated device block alerts	rule_engine	{"priority": "P1", "final_score": 820, "alerts_added": [57, 58]}	2026-06-23 09:40:15
4	2	CASE_ASSIGNED	Case 2 assigned to checker	admin	{"assigned_to": "checker", "prev_assignee": "UNASSIGNED", "assignment_reason": "Device alert triage"}	2026-06-23 09:55:00
5	3	CASE_CREATED	Case created from device alert with prior case history	rule_engine	{"priority": "P2", "final_score": 710, "alerts_added": [61]}	2026-06-23 09:50:15
6	3	CASE_UPDATED	Case 3 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P2", "risk_score": 71}	2026-06-23 10:14:53.994492
7	3	CASE_ASSIGNED	Case 3 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-06-23 10:14:54.086102
8	4	CASE_CREATED	Case created from cross-service hits for Aarav Sharma	rule_engine	{"final_score": 980, "alerts_added": [122, 56, 1, 63]}	2026-06-29 09:40:00
9	4	CASE_ASSIGNED	Case assigned to admin	system	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED"}	2026-06-29 09:41:00
10	5	CASE_CREATED	Case created from transaction and device hits for Bhavna Rao	rule_engine	{"final_score": 860, "alerts_added": [2, 64]}	2026-06-29 09:45:00
11	5	CASE_ASSIGNED	Case assigned to checker	system	{"assigned_to": "checker", "prev_assignee": "UNASSIGNED"}	2026-06-29 09:46:00
12	6	CASE_CREATED	Case created from screening-only alert for Chirag Nair	rule_engine	{"final_score": 780, "alerts_added": [123]}	2026-06-29 08:45:00
13	7	CASE_CREATED	Case created from sanctions and adverse media alerts for Delta Exports	rule_engine	{"final_score": 940, "alerts_added": [124, 57]}	2026-06-29 08:20:00
14	8	CASE_CREATED	Case created from device-fraud alert for Farhan Ali	rule_engine	{"final_score": 720, "alerts_added": [65]}	2026-06-29 10:20:00
15	8	CASE_UPDATED	Case 8 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P2", "risk_score": 72}	2026-06-29 07:12:27.650039
16	4	CASE_UPDATED	Case 4 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P1", "risk_score": 98}	2026-06-29 07:39:37.700725
17	6	CASE_UPDATED	Case 6 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P2", "risk_score": 78}	2026-06-29 07:41:51.878664
124	42	CASE_UPDATED	Case 42 updated	admin	{"audit": {"status": "ESCALATED"}, "priority": "P1", "risk_score": 85}	2026-07-01 20:57:28.211603
128	45	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P4", "final_score": 37, "alerts_added": [{"alert_id": 44, "alert_type": "TRANSACTION", "alert_score": 122, "alert_source_table": "transaction_alert"}], "triggered_by": "admin"}	2026-07-02 07:13:12.413941
130	45	CASE_ASSIGNED	Case 45 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-02 07:13:20.180174
133	46	CASE_ASSIGNED	Case 46 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-02 13:35:06.528135
137	48	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P4", "final_score": 236, "alerts_added": [{"alert_id": 56, "alert_type": "TRANSACTION", "alert_score": 785, "alert_source_table": "transaction_alert"}], "triggered_by": "admin"}	2026-07-04 07:47:54.509997
143	49	CASE_UPDATED	Case 49 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P2", "risk_score": 500}	2026-07-08 14:39:26.811509
146	50	CASE_UPDATED	Case 50 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P2", "risk_score": 500}	2026-07-08 17:01:30.921588
149	2	CASE_UPDATED	Case updated with 1 new alert(s)	rule_engine	{"priority": "P4", "final_score": 22, "alerts_added": [{"alert_id": 114, "alert_type": "DEVICE", "alert_score": 102, "alert_source_table": "device_alert"}], "triggered_by": "rule_engine"}	2026-07-09 10:23:28.04253
154	51	CASE_ASSIGNED	Case 51 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-09 17:14:31.112513
155	51	CASE_DECISION_SUBMITTED	Decision CONFIRMED_FRAUD submitted for case 51	admin	{"decision_code": "CONFIRMED_FRAUD", "requires_approval": false}	2026-07-09 17:14:50.103197
156	51	CASE_ACTION_QUEUED	Action BLOCK_CARD queued	admin	{"action_code": "BLOCK_CARD", "execution_id": 9}	2026-07-09 17:14:50.111482
157	51	CASE_ACTION_QUEUED	Action SEND_CUSTOMER_NOTIFICATION queued	admin	{"action_code": "SEND_CUSTOMER_NOTIFICATION", "execution_id": 10}	2026-07-09 17:14:50.121476
158	51	CASE_ACTION_DISPATCHED	Configured decision actions queued for dispatch	admin	{"case_id": 51, "queued_actions": ["BLOCK_CARD", "SEND_CUSTOMER_NOTIFICATION"]}	2026-07-09 17:14:50.12148
159	51	CASE_RISK_EVENT_RECORDED	Risk event recorded for decision CONFIRMED_FRAUD	admin	{"score": 900, "reference_id": "51"}	2026-07-09 17:14:50.20319
160	51	CASE_CLOSED	Case 51 closed with decision CONFIRMED_FRAUD	admin	{"status": "CLOSED", "decision_code": "CONFIRMED_FRAUD"}	2026-07-09 17:14:50.203193
161	48	CASE_UPDATED	Case updated with 0 new alert(s)	admin	{"priority": "P1", "final_score": 787, "alerts_added": [], "triggered_by": "admin"}	2026-07-09 17:26:16.909116
164	51	EVIDENCE_UPLOAD	Evidence uploaded: opensanctions-sources-2026-07-12.csv	admin	{"version": 2, "filename": "opensanctions-sources-2026-07-12.csv", "file_path": "data/case_evidence/51/opensanctions-sources-2026-07-12_v2.csv", "file_type": "text/csv", "evidence_id": 2}	2026-07-13 10:30:38.683243
167	53	CASE_UPDATED	Case updated with 1 new alert(s)	adverse_media_service	{"priority": "P2", "final_score": 500, "alerts_added": [{"alert_id": 92, "alert_type": "SCREENING", "alert_score": 100, "alert_source_table": "adverse_alert"}], "triggered_by": "adverse_media_service"}	2026-07-14 08:52:18.636513
103	41	CASE_CREATED	Case created from screening alert for Rohan Malhotra	rule_engine	{"priority": "P1", "risk_score": 780, "alerts_added": [149]}	2026-06-30 09:06:00
104	41	CASE_UPDATED	Adverse media alert merged into existing case for Rohan Malhotra	rule_engine	{"priority": "P1", "risk_score": 815, "alerts_added": [82]}	2026-06-30 09:10:00
105	41	CASE_UPDATED	First device alert merged into existing case for Rohan Malhotra	rule_engine	{"priority": "P1", "risk_score": 890, "alerts_added": [108]}	2026-06-30 09:25:00
106	41	CASE_UPDATED	First transaction alert merged into existing case for Rohan Malhotra	rule_engine	{"priority": "P1", "risk_score": 925, "alerts_added": [40]}	2026-06-30 09:32:00
107	41	CASE_UPDATED	Latest device and transaction alerts merged into existing case for Rohan Malhotra	rule_engine	{"priority": "P1", "risk_score": 965, "alerts_added": [109, 41]}	2026-06-30 09:38:00
108	42	CASE_CREATED	Case created from first device anomaly for Meera Sethi	rule_engine	{"priority": "P1", "risk_score": 690, "alerts_added": [110]}	2026-06-30 09:44:00
109	42	CASE_UPDATED	First ATM alert merged into existing case for Meera Sethi	rule_engine	{"priority": "P1", "risk_score": 780, "alerts_added": [42]}	2026-06-30 09:48:00
110	42	CASE_UPDATED	Second device anomaly merged into existing case for Meera Sethi	rule_engine	{"priority": "P1", "risk_score": 815, "alerts_added": [111]}	2026-06-30 09:52:00
111	42	CASE_UPDATED	Second ATM alert merged into existing case for Meera Sethi	rule_engine	{"priority": "P1", "risk_score": 845, "alerts_added": [43]}	2026-06-30 09:55:00
112	43	CASE_CREATED	Case created from first device anomaly for Neha Kapoor	rule_engine	{"priority": "P2", "risk_score": 690, "alerts_added": [112]}	2026-06-30 10:07:00
113	43	CASE_UPDATED	Second device anomaly merged into existing case for Neha Kapoor	rule_engine	{"priority": "P2", "risk_score": 735, "alerts_added": [113]}	2026-06-30 10:15:00
114	44	CASE_CREATED	Case created from screening escalation for Vikram Desai	rule_engine	{"priority": "P2", "risk_score": 705, "alerts_added": [151]}	2026-06-30 07:56:00
125	42	CASE_DECISION_SUBMITTED	Decision CONFIRMED_FRAUD submitted for case 42	admin	{"decision_code": "CONFIRMED_FRAUD", "requires_approval": false}	2026-07-01 21:02:49.102567
126	7	CASE_UPDATED	Case 7 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P1", "risk_score": 94}	2026-07-01 21:04:32.122489
129	45	CASE_UPDATED	Case 45 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P4", "risk_score": 37}	2026-07-02 07:13:20.125701
140	48	CASE_UPDATED	Case 48 updated	admin	{"audit": {"alert_ids": {"device_result": [], "adverse_result": [], "screening_result": [157], "transaction_result": [56]}}, "priority": "P4", "risk_score": 236, "device_result": [], "adverse_result": [], "screening_result": [157], "transaction_result": [56]}	2026-07-04 20:33:30.541991
162	4	CASE_ALERT_DECISION_SUBMITTED	Decision ATTEMPTED_FRAUD submitted for 1 alert mapping(s)	admin	{"mapping_ids": [8], "decision_code": "ATTEMPTED_FRAUD", "alert_mappings": [{"alert_id": 122, "alert_type": "SCREENING", "mapping_id": 8, "alert_source_table": "screening_alert"}]}	2026-07-10 15:01:48.788281
115	41	CASE_DECISION_SUBMITTED	Confirmed Fraud decision submitted	fraud_lead	{"demo_seed": "OUTCOME_DECISION_V1", "loss_amount": 18500, "decision_code": "CONFIRMED_FRAUD"}	2026-07-01 23:09:43.847145
116	41	CASE_ACTION_DISPATCHED	Mandatory actions dispatched for confirmed fraud case	case-action-worker	{"demo_seed": "OUTCOME_DECISION_V1", "mandatory_actions": ["BLOCK_CARD", "CREATE_RECOVERY"]}	2026-07-01 23:18:43.847145
117	41	CASE_CLOSED	Case closed after mandatory actions were sent	case-action-worker	{"demo_seed": "OUTCOME_DECISION_V1", "closure_rule": "mandatory_actions_sent"}	2026-07-02 00:04:43.847145
118	42	CASE_DECISION_SUBMITTED	Reverse Transaction decision submitted	ops_checker	{"demo_seed": "OUTCOME_DECISION_V1", "loss_amount": 42000, "decision_code": "REVERSE_TRANSACTION"}	2026-07-01 23:59:43.847145
119	42	CASE_DECISION_APPROVED	Reverse Transaction decision approved by supervisor	fraud_supervisor	{"demo_seed": "OUTCOME_DECISION_V1", "approval_status": "APPROVED"}	2026-07-02 00:12:43.847145
120	42	CASE_ACTION_FAILED	Core banking reversal action exhausted retries	case-action-worker	{"error": "HTTP 504", "demo_seed": "OUTCOME_DECISION_V1", "action_code": "REVERSE_TRANSACTION", "retry_count": 3}	2026-07-02 01:36:43.847145
121	43	CASE_DECISION_SUBMITTED	Device Compromised decision submitted	device_ops	{"demo_seed": "OUTCOME_DECISION_V1", "device_id": "UP-DEV-99102", "decision_code": "DEVICE_COMPROMISED"}	2026-07-02 01:19:43.847145
122	43	CASE_ACTION_SENT	Device blacklist request accepted by Device Risk Engine	case-action-worker	{"demo_seed": "OUTCOME_DECISION_V1", "action_code": "DEVICE_BLACKLIST", "business_status": "AWAITING_CONFIRMATION"}	2026-07-02 01:25:43.847145
123	44	CASE_DECISION_SUBMITTED	STR Recommended decision submitted and awaiting approval	aml_ops	{"demo_seed": "OUTCOME_DECISION_V1", "decision_code": "STR_RECOMMENDED", "approval_status": "PENDING"}	2026-07-02 01:32:43.847145
127	1	CASE_UPDATED	Case 1 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P1", "risk_score": 96}	2026-07-02 07:12:48.144326
131	46	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P3", "final_score": 395, "alerts_added": [{"alert_id": 150, "alert_type": "SCREENING", "alert_score": 790, "alert_source_table": "screening_alert"}], "triggered_by": "admin"}	2026-07-02 13:34:56.192287
132	46	CASE_UPDATED	Case 46 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P3", "risk_score": 395}	2026-07-02 13:35:06.481022
134	47	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P4", "final_score": 44, "alerts_added": [{"alert_id": 84, "alert_type": "SCREENING", "alert_score": 88, "alert_source_table": "adverse_alert"}], "triggered_by": "admin"}	2026-07-04 07:46:38.441597
135	47	CASE_UPDATED	Case 47 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P4", "risk_score": 44}	2026-07-04 07:46:44.88491
136	47	CASE_ASSIGNED	Case 47 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-04 07:46:44.927899
138	48	CASE_UPDATED	Case 48 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P4", "risk_score": 236}	2026-07-04 07:48:03.51436
139	48	CASE_ASSIGNED	Case 48 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-04 07:48:03.555732
141	44	CASE_UPDATED	Case 44 updated	admin	{"audit": {"alert_ids": {"device_result": [], "adverse_result": [], "screening_result": [151, 159], "transaction_result": []}}, "priority": "P2", "risk_score": 71, "device_result": [], "adverse_result": [], "screening_result": [151, 159], "transaction_result": []}	2026-07-04 20:36:01.098321
142	49	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P2", "final_score": 500, "alerts_added": [{"alert_id": 160, "alert_type": "SCREENING", "alert_score": 1000, "alert_source_table": "screening_alert"}], "triggered_by": "admin"}	2026-07-08 14:39:19.483383
144	49	CASE_ASSIGNED	Case 49 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-08 14:39:26.861676
145	50	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P2", "final_score": 500, "alerts_added": [{"alert_id": 161, "alert_type": "SCREENING", "alert_score": 1000, "alert_source_table": "screening_alert"}], "triggered_by": "admin"}	2026-07-08 17:01:21.551251
147	50	CASE_ASSIGNED	Case 50 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-08 17:01:30.969633
148	3	CASE_UPDATED	Case updated with 1 new alert(s)	admin	{"priority": "P4", "final_score": 15, "alerts_added": [{"alert_id": 62, "alert_type": "DEVICE", "alert_score": 77, "alert_source_table": "device_alert"}], "triggered_by": "admin"}	2026-07-09 07:42:15.215119
150	2	CASE_UPDATED	Case updated with 1 new alert(s)	rule_engine	{"priority": "P4", "final_score": 22, "alerts_added": [{"alert_id": 115, "alert_type": "DEVICE", "alert_score": 102, "alert_source_table": "device_alert"}], "triggered_by": "rule_engine"}	2026-07-09 17:09:06.379827
151	44	CASE_ALERT_DECISION_SUBMITTED	Decision FALSE_POSITIVE submitted for 2 alert mapping(s)	analyst1	{"mapping_ids": [130, 124], "decision_code": "FALSE_POSITIVE", "alert_mappings": [{"alert_id": 159, "alert_type": "SCREENING", "mapping_id": 130, "alert_source_table": "screening_alert"}, {"alert_id": 151, "alert_type": "SCREENING", "mapping_id": 124, "alert_source_table": "screening_alert"}]}	2026-07-09 17:11:11.931253
152	51	CASE_CREATED	Case created with 1 new alert(s)	admin	{"priority": "P4", "final_score": 273, "alerts_added": [{"alert_id": 55, "alert_type": "TRANSACTION", "alert_score": 910, "alert_source_table": "transaction_alert"}], "triggered_by": "admin"}	2026-07-09 17:14:16.962269
153	51	CASE_UPDATED	Case 51 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P4", "risk_score": 273}	2026-07-09 17:14:31.071725
163	51	EVIDENCE_UPLOAD	Evidence uploaded: FinFactory - Fueling FinTech Futures.pdf	admin	{"version": 1, "filename": "FinFactory - Fueling FinTech Futures.pdf", "file_path": "data/case_evidence/51/FinFactory_-_Fueling_FinTech_Futures_v1.pdf", "file_type": "application/pdf", "evidence_id": 1}	2026-07-13 10:30:22.403467
165	52	CASE_CREATED	Case created with 1 new alert(s)	screening_service	{"priority": "P2", "final_score": 500, "alerts_added": [{"alert_id": 162, "alert_type": "SCREENING", "alert_score": 1000, "alert_source_table": "screening_alert"}], "triggered_by": "screening_engine"}	2026-07-14 08:20:00.064712
166	53	CASE_CREATED	Case created with 1 new alert(s)	screening_service	{"priority": "P2", "final_score": 500, "alerts_added": [{"alert_id": 163, "alert_type": "SCREENING", "alert_score": 1000, "alert_source_table": "screening_alert"}], "triggered_by": "screening_engine"}	2026-07-14 08:50:03.687563
168	53	CASE_UPDATED	Case 53 updated	admin	{"audit": {"status": "IN_PROGRESS"}, "priority": "P2", "risk_score": 500}	2026-07-19 11:08:14.838243
169	53	CASE_ASSIGNED	Case 53 assigned to admin	admin	{"assigned_to": "admin", "prev_assignee": "UNASSIGNED", "assignment_reason": "self picked"}	2026-07-19 11:08:14.984294
\.


--
-- Data for Name: case_master; Type: TABLE DATA; Schema: efrm; Owner: -
--

COPY efrm.case_master (case_id, entity_type, entity_id, risk_score, priority, status, created_at, updated_at, assigned_to, sla_due_at, disposition_code, disposition_details, closure_reason, is_str_recommended, is_ctr_recommended, sla_id, sla_response_due_at, sla_resolution_due_at, sla_status, alert_count, category_count, max_alert_score, scoring_version, is_override_case, override_reason, entity_name, institution_id, decision_code, decision_payload, decision_remarks, decision_submitted_by, decision_submitted_at, approval_status, approved_by, approved_at) FROM stdin;
42	CUSTOMER	C00028012	85	P1	ACTION_FAILED	2026-06-30 09:44:00	2026-07-02 12:51:17.544007	ops_checker	2026-06-30 13:44:00	CONFIRMED_FRAUD	Reversal action pending operational resolution.	UPI debit identified as fraud. Supervisor approved reversal, but core banking reversal API is failing after retries.	N	N	2102	2026-06-30 10:14:00	2026-06-30 12:44:00	ACTIVE	4	2	181	2	N	\N	Meera Sethi	KANJI	CONFIRMED_FRAUD	{"loss_amount": 7.0, "evidence_ids": [], "action_preview": [{"action_code": "BLOCK_CARD", "sequence_no": 1, "is_mandatory": true}, {"action_code": "CREATE_RECOVERY", "sequence_no": 2, "is_mandatory": true}, {"action_code": "UPDATE_CUSTOMER_RISK", "sequence_no": 3, "is_mandatory": false}, {"action_code": "SEND_CUSTOMER_NOTIFICATION", "sequence_no": 4, "is_mandatory": false}], "recovery_required": false}	UPI debit identified as fraud. Supervisor approved reversal, but core banking reversal API is failing after retries.	admin	2026-07-01 21:02:49.09012	NOT_REQUIRED	\N	\N
1	ORGANIZATION	ORG00001	96	P1	IN_PROGRESS	2026-06-23 09:30:00	2026-07-02 12:51:17.544007	admin	2026-06-23 11:30:00	\N	\N	\N	N	N	4	2026-06-23 10:00:00	2026-06-23 11:30:00	OPEN	4	1	1000	1	N	\N	ABC PRIVATE LIMITED	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
8	CUSTOMER	KANJI_REL_F_CUST	72	P2	IN_PROGRESS	2026-06-29 10:20:00	2026-07-02 12:51:17.544007	device_ops	2026-06-29 13:20:00	\N	\N	\N	N	N	1005	2026-06-29 10:50:00	2026-06-29 12:20:00	ACTIVE	1	1	150	1	N	\N	Farhan Ali	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
45	CUSTOMER	C00028015	37	P4	IN_PROGRESS	2026-07-02 07:13:12.38142	2026-07-02 12:51:17.544007	admin	2026-07-02 11:00:00	\N	\N	\N	N	N	11	2026-07-02 09:30:00	2026-07-02 11:00:00	OPEN	1	1	122	1	N	\N	Siddharth Rao	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
7	ORGANIZATION	KANJI_REL_D_ORG	94	P1	IN_PROGRESS	2026-06-29 08:20:00	2026-07-02 12:51:17.544007	sanctions_team	2026-06-29 11:20:00	\N	\N	\N	Y	N	1004	2026-06-29 08:50:00	2026-06-29 10:20:00	ACTIVE	2	2	1000	1	N	\N	Delta Exports Private Limited	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
3	CUSTOMER	OA5B61E340CF3A11F0A2A32BE01C4E89EG	15	P4	IN_PROGRESS	2026-06-23 09:50:00	2026-07-09 07:42:15.200531	admin	2026-07-09 11:00:00	\N	\N	\N	N	N	15	2026-07-09 09:30:00	2026-07-09 11:00:00	OPEN	2	1	77	1	N	\N	KANJI DEVICE CUSTOMER EG	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
6	CUSTOMER	KANJI_REL_C_CUST	78	P2	IN_PROGRESS	2026-06-29 08:45:00	2026-07-02 12:51:17.544007	aml_ops	2026-06-29 11:45:00	\N	\N	\N	N	N	1003	2026-06-29 09:15:00	2026-06-29 10:45:00	ACTIVE	1	1	810	1	N	\N	Chirag Nair	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
5	CUSTOMER	KANJI_REL_B_CUST	86	P1	IN_PROGRESS	2026-06-29 09:45:00	2026-07-02 12:51:17.544007	checker	2026-06-29 12:45:00	\N	\N	\N	N	N	1002	2026-06-29 10:15:00	2026-06-29 11:45:00	ACTIVE	2	2	187	1	N	\N	Bhavna Rao	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
4	CUSTOMER	KANJI_REL_A_CUST	98	P1	IN_PROGRESS	2026-06-29 09:40:00	2026-07-02 12:51:17.544007	admin	2026-06-29 12:40:00	\N	\N	\N	Y	N	1001	2026-06-29 10:10:00	2026-06-29 11:40:00	ACTIVE	4	4	930	1	N	\N	Aarav Sharma	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
41	CUSTOMER	C00028011	97	P1	CLOSED	2026-06-30 09:06:00	2026-07-02 12:51:17.544007	fraud_lead	2026-06-30 13:06:00	CONFIRMED_FRAUD	Confirmed unauthorized card transaction. Mandatory block and recovery actions sent.	Confirmed fraud decision completed with mandatory actions dispatched.	Y	N	2101	2026-06-30 09:36:00	2026-06-30 12:06:00	ACTIVE	6	4	910	2	N	\N	Rohan Malhotra	KANJI	CONFIRMED_FRAUD	{"channel": "UPI_CARD", "currency": "INR", "card_last4": "8842", "loss_amount": 18500, "recovery_required": true, "customer_confirmation": "Unauthorized ATM withdrawal confirmed over recorded call", "external_case_reference": "UP-FRD-20260702-0041"}	Customer denied ATM cash withdrawal at Andheri East. Card blocked and recovery initiated.	fraud_lead	2026-07-01 23:09:43.847145	NOT_REQUIRED	\N	\N
43	CUSTOMER	C00028016	74	P2	ACTION_PENDING	2026-06-30 10:07:00	2026-07-02 12:51:17.544007	device_ops	2026-06-30 13:07:00	DEVICE_COMPROMISED	Device risk actions in progress.	\N	N	N	2103	2026-06-30 10:37:00	2026-06-30 12:07:00	ACTIVE	2	1	170	2	N	\N	Neha Kapoor	KANJI	DEVICE_COMPROMISED	{"reason": "Rooted device with cloned app fingerprint", "device_id": "UP-DEV-99102", "ip_address": "103.88.44.19", "external_case_reference": "UP-DEV-20260702-0043"}	Device fingerprint shows emulator/root indicators. Device blacklist sent; password reset action is pending dispatch.	device_ops	2026-07-02 01:19:43.847145	NOT_REQUIRED	\N	\N
50	MERCHANT	TEST-AMC-CHAIN-LOCAL-002	500	P2	IN_PROGRESS	2026-07-08 17:01:21.508285	2026-07-08 17:01:30.965118	admin	2026-07-09 11:00:00	\N	\N	\N	N	N	5	2026-07-09 09:30:00	2026-07-09 11:00:00	OPEN	1	1	1000	1	N	\N	AL ZAWAHIRI, Dr. Ayman	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
46	CUSTOMER	C00028013	395	P3	IN_PROGRESS	2026-07-02 13:34:56.15128	2026-07-02 13:35:06.522652	admin	2026-07-02 15:34:56.132221	\N	\N	\N	N	N	6	2026-07-02 14:04:56.132221	2026-07-02 15:34:56.132221	OPEN	1	1	790	1	N	\N	Arvind Menon	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
2	CUSTOMER	OA5B61E340CF3A11F0A2A32BE01C4E89EF	22	P4	IN_PROGRESS	2026-06-23 09:40:00	2026-07-09 17:09:06.372	checker	2026-07-10 11:00:00	\N	\N	\N	N	N	15	2026-07-10 09:30:00	2026-07-10 11:00:00	OPEN	4	1	102	1	N	\N	KANJI DEVICE CUSTOMER EF	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
47	CUSTOMER	C00028018	44	P4	IN_PROGRESS	2026-07-04 07:46:38.395184	2026-07-04 07:46:44.923236	admin	2026-07-06 11:00:00	\N	\N	\N	N	N	7	2026-07-06 09:30:00	2026-07-06 11:00:00	OPEN	1	1	88	1	N	\N	Priyanka Iyer	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
51	CUSTOMER	KANJI_MER_9302	273	P4	CLOSED	2026-07-09 17:14:16.931531	2026-07-09 17:14:50.199881	admin	2026-07-10 11:00:00	CONFIRMED_FRAUD	fwefw	fwefw	Y	N	11	2026-07-10 09:30:00	2026-07-10 11:00:00	OPEN	1	1	910	1	N	\N	NorthStar Exports LLP	KANJI	CONFIRMED_FRAUD	{"loss_amount": 1000.0, "evidence_ids": [], "action_preview": [{"action_code": "BLOCK_CARD", "sequence_no": 1, "is_mandatory": true}, {"action_code": "SEND_CUSTOMER_NOTIFICATION", "sequence_no": 2, "is_mandatory": false}], "str_recommended": true, "recovery_required": true}	fwefw	admin	2026-07-09 17:14:50.069801	NOT_REQUIRED	\N	\N
44	CUSTOMER	C00028017	71	P2	PENDING_APPROVAL	2026-06-30 07:56:00	2026-07-04 20:36:01.097052	aml_ops	2026-06-30 10:56:00	STR_RECOMMENDED	Awaiting MLRO/supervisor approval before STR package generation.	\N	N	N	2104	2026-06-30 08:26:00	2026-06-30 09:56:00	ACTIVE	2	1	780	2	N	\N	Vikram Desai	KANJI	STR_RECOMMENDED	{"str_reason": "Layering pattern with mule-account indicators", "evidence_ids": [9011, 9012], "linked_accounts": ["C00028017", "C00028022"], "external_case_reference": "UP-AML-20260702-0044"}	AML analyst recommends STR due to repeated high-risk inbound credits followed by rapid outward transfers.	aml_ops	2026-07-02 01:32:43.847145	PENDING	\N	\N
48	CUSTOMER	KANJI_ORG_9402	787	P1	IN_PROGRESS	2026-07-04 07:47:54.489723	2026-07-09 17:26:16.898664	admin	2026-07-10 11:00:00	\N	\N	\N	N	N	8	2026-07-10 09:30:00	2026-07-10 11:00:00	OPEN	2	2	960	1	N	\N	Rivergate Commodities FZE	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
49	MERCHANT	TEST-OFAC-ENHANCED-001	500	P2	IN_PROGRESS	2026-07-08 14:39:19.429451	2026-07-08 14:39:26.857067	admin	2026-07-08 16:39:19.404516	\N	\N	\N	N	N	5	2026-07-08 15:09:19.404516	2026-07-08 16:39:19.404516	OPEN	1	1	1000	1	N	\N	AL ZAWAHIRI, Dr. Ayman	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
52	CUSTOMER	TEST-OFAC-HAMZA-002	500	P2	OPEN	2026-07-14 08:20:00.034949	2026-07-14 08:20:00.05133	\N	2026-07-14 11:00:00	\N	\N	\N	N	N	5	2026-07-14 09:30:00	2026-07-14 11:00:00	OPEN	1	1	1000	1	N	\N	BIN LADIN	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
53	CUSTOMER	TEST-OFAC-NASRALLAH-AMC-001	500	P2	IN_PROGRESS	2026-07-14 08:50:03.677157	2026-07-19 11:08:14.980416	admin	2026-07-14 11:00:00	\N	\N	\N	N	N	5	2026-07-14 09:30:00	2026-07-14 11:00:00	OPEN	2	1	1000	1	N	\N	NASRALLAH	KANJI	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: case_recovery; Type: TABLE DATA; Schema: efrm; Owner: -
--

COPY efrm.case_recovery (recovery_id, case_id, initial_loss_amount, provisional_credit, recovered_amount, writeoff_amount, updated_at) FROM stdin;
\.


--
-- PostgreSQL database dump complete
--

\unrestrict IGHdgNddtDmsrS4p7zufAoyXbg5CbqqrJhcOqrweQaG3a3tx208ITtthq5JG6OA

