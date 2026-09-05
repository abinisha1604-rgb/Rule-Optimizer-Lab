--
-- PostgreSQL database dump
--

\restrict igKPVRMcjPtdT8IZZxp6NwhsQZN9B4sJm4RgiIdiLJVerBj50xUeGHHPl15BrK1

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
-- Data for Name: rule_master; Type: TABLE DATA; Schema: efrm; Owner: ganesh
--

COPY efrm.rule_master (id, rule_code, name, rule_type, fact, description, created_by, created_at) FROM stdin;
28	DEVICE_EMULATOR_DETECTED	Block activity originating from emulator devices.	DEVICE	DEVICE	Block activity originating from emulator devices.	admin	2026-03-10 06:42:38.860138
29	DEVICE_ROOTED_DEVICE_USAGE	Rooted Device Usage	FRM	DEVICE	Rooted or jailbroken device attempting login	SYSTEM	2026-03-11 15:23:44.663667
30	DEVICE_TAMPERED_APPLICATION	Device Application Tampering	FRM	DEVICE	Mobile application tampering detected	SYSTEM	2026-03-11 15:29:52.540791
31	DEVICE_VPN_LOGIN	VPN Login Detection	FRM	DEVICE	Login attempt using VPN network	SYSTEM	2026-03-11 15:30:31.08541
32	DEVICE_PROXY_USAGE	Proxy Network Usage	FRM	DEVICE	Device activity through proxy infrastructure	SYSTEM	2026-03-11 15:31:04.04416
33	DEVICE_TOR_NETWORK_USAGE	TOR Network Usage	FRM	DEVICE	Access attempt through TOR anonymity network	SYSTEM	2026-03-11 15:31:37.539735
34	DEVICE_DISPOSABLE_EMAIL	Disposable Email Usage	FRM	DEVICE	Disposable email detected during onboarding	SYSTEM	2026-03-11 15:59:53.524614
36	DEVICE_VPN_NEW_DEVICE_LOGIN	VPN Login from New Device	FRM	DEVICE	Login from new device through VPN network	SYSTEM	2026-03-11 16:01:08.080553
37	DEVICE_MULTIPLE_FINTECH_USAGE	Multiple Fintech Identity Usage	AML	DEVICE	Identity detected across multiple fintech platforms	SYSTEM	2026-03-11 16:01:44.163332
38	DEVICE_ACCOUNT_FARM_PATTERN	Device Account Farm Pattern	FRM	DEVICE	Customer uses multiple device	SYSTEM	2026-03-11 16:02:29.831888
39	BLACKLISTED_IP	Blacklist IP	DEVICE	DEVICE	Check on Blacklisted IP	admin	2026-03-12 11:04:13.452387
40	BLACKLISTED_DEVICE	Blacklist Device	DEVICE	DEVICE	Check on Blacklisted Device	admin	2026-03-12 11:04:13.452387
41	BLACKLISTED_PINCODE	Blacklist Pincode	DEVICE	DEVICE	Check on Blacklisted Pincode	admin	2026-03-12 11:04:13.452387
42	HIGH_RISK_CITY	High Risk Cities	DEVICE	DEVICE	Check on High Risk Cities	admin	2026-03-14 05:30:00.757721
43	HIGH_RISK_COUNTRY	High Risk Country Check	DEVICE	DEVICE	High Risk Country Check	admin	2026-03-14 07:09:48.04431
44	DEVICE_LOGIN_VELOCITY	Device Login Velocity	FRM	DEVICE	Excessive login attempts from same device	SYSTEM	2026-03-14 12:43:44.000804
47	DEVICE_LOCALITY_CHANGE_ANOMALY	Device Geo Velocity	FRM	DEVICE	Device observed across multiple localities or countries in short duration	SYSTEM	2026-03-14 14:13:06.187167
49	DEVICE_IMPOSSIBLE_TRAVEL	Device Impossible Travel Detection	FRM	DEVICE	Detects device travelling geographically impossible distance between logins	SYSTEM	2026-03-14 14:48:28.823174
50	DEVICE_APP_HOOKING_DETECTED	Device Hooking detected	DEVICE	DEVICE	Device Hooking detected	admin	2026-03-16 06:04:22.920254
51	DEVICE_SCREEN_MIRRORING	Device Screen Mirroring detected	DEVICE	DEVICE	Device Screen Mirroring detected	admin	2026-03-16 06:07:09.046702
52	DEVICE_REMOTE_CONTROL_TOOL	Device Remote Control Tools detected	DEVICE	DEVICE	Device Remote Control Tools detected	admin	2026-03-16 06:18:32.649996
54	DEVICE_IP_ROTATION_PATTERN	Device used multiple IP in short duration	DEVICE	DEVICE	Device used multiple IP in short duration	admin	2026-03-16 06:41:09.49367
55	DEVICE_SESSION_BURST	More session detected in short duration	DEVICE	DEVICE	More session detected in short duration	admin	2026-03-16 06:58:23.360642
56	DEVICE_CLONED_DETECTED	Device Cloning Detected	DEVICE	DEVICE	Device Cloning Detected	admin	2026-03-16 07:04:17.818782
1	CUST_DEBIT_CUST_CREDIT_7D	Customer debit vs Customer Credit in 7 days	AML	TRANSACTION	Rule triggers when ALL of the following conditions are met:\n\n1. transaction.drCrIndicator is equal to D\n  AND\n2. Total Debit Amount - 7 Days (Customer Level Entity) is greater than or equal to (Total Credit Amount - 7 Days (Customer Level Entity) ÷ 0.9)	admin	2026-02-20 08:32:06.269919
2	CUST_DEBIT_70_95_BAND	Debit between 70%–95% of 7-day credit (structuring band).	AML	TRANSACTION	Rule triggers when ALL of the following conditions are met:\n\n1. transaction.drCrIndicator is equal to D\n  AND\n  [AND group:]\n  2. Total Debit Amount - 7 Days (Customer Level Entity) is greater than or equal to 70% of Total Credit Amount - 7 Days (Customer Level Entity)\n  3. Total Debit Amount - 7 Days (Customer Level Entity) is less than or equal to 90% of Total Credit Amount - 7 Days (Customer Level Entity)	admin	2026-02-20 10:02:41.111111
3	CUST_SPEND_2_4X_AVG	Current transaction ≥ 2–4X historical 30-day average spend.	FRM	TRANSACTION	Rule triggers when ALL of the following conditions are met:\n\n1. transaction.drCrIndicator is equal to D\n  AND\n2. field:transaction.drCrAmount is greater than or equal to (Average Debit Amount - 30 Days (Customer Level Entity) × $LIMIT_AND_COUNT.CUST_AVG_SPEND_MULTIPLIER)	admin	2026-02-20 12:04:45.951614
4	CUST_SUDDEN_INTL_USAGE	Customer historically domestic suddenly transacting internationally.	ALERT	TRANSACTION	1	admin	2026-02-21 04:44:32.778831
5	CUST_HIGH_UTILIZATION_SPIKE	Customer overall card utilization ratio ≥ threshold.	FRM	TRANSACTION	Rule triggers when ALL of the following conditions are met:\n\n1. Customer utilization ratio - 30 Days (Customer Level Entity) is greater than or equal to LIMIT_AND_COUNT.CUST_UTILIZATION_LIMIT	admin	2026-02-21 06:17:41.896496
6	CUST_MULTI_BENEFICIARY_FUNDING	Same customer funding multiple beneficiaries in short time.	AML	TRANSACTION	1	admin	2026-02-21 06:54:45.345243
7	CUST_TIME_OF_DAY_ANOMALY	Txn outside normal historical hour band.	ALERT	TRANSACTION	Rule triggers when ALL of the following conditions are met:\n\n1. field:transaction.txnHour is less than Customer Normal Transaction Start Hour (30 Days) (Customer Level Entity)\n  AND\n2. field:transaction.txnHour is greater than Customer Normal Transaction End Hour (30 Days) (Customer Level Entity)	admin	2026-02-21 08:33:03.764477
8	CUST_NEAR_LIMIT_PATTERN	Transaction ≥ 90% available Limit.	ALERT	TRANSACTION	1	admin	2026-02-21 09:42:39.388758
9	CUST_STRUCTURED_AMOUNT_PATTERN	Customer performs repeated transactions just below a defined threshold amount within a defined time window.	FRM	TRANSACTION	Rule triggers when ALL of the following conditions are met:\n\n1. transaction.drCrAmount is greater than or equal to \n  AND\n2. Customer Near Threshold Transaction Count - 7 Days (Customer Level Entity) is greater than or equal to $LIMIT_AND_COUNT.STRUCTURING_TXN_COUNT_LIMIT	admin	2026-02-21 10:18:32.332382
10	ATM_HIGH_VALUE_TXN	ATM High Value Withdrawal	FRAUD	TRANSACTION	Block unusually high single ATM withdrawal based on issuer threshold.	SYSTEM	2026-02-23 10:40:27.118157
11	ATM_VELOCITY_5MIN_CARD	ATM Velocity - 5 Minutes	FRAUD	TRANSACTION	Multiple ATM withdrawals within 5 minutes on same card.	SYSTEM	2026-02-23 10:59:26.020656
12	ATM_AMOUNT_1HOUR_CARD	ATM 1 Hour Amount Spike - Card	FRAUD	TRANSACTION	Total ATM withdrawal amount exceeds threshold in 1 hour (card level).	SYSTEM	2026-02-23 11:22:07.206597
13	ATM_GEO_VELOCITY_CARD	ATM Geo Velocity - Card	FRAUD	TRANSACTION	Impossible travel between ATM locations within short time window.	SYSTEM	2026-02-23 11:47:49.366943
14	ATM_DORMANT_CARD_HIGH_WITHDRAWAL	ATM Dormant Card High Withdrawal	FRAUD	TRANSACTION	Card inactive for long duration, now high value ATM withdrawal.	SYSTEM	2026-02-23 11:54:12.821767
15	ATM_WITHDRAWAL_90_PERCENT_CREDIT_CUSTOMER	ATM Withdrawal ≥ 90% of 7-Day Credit	FRAUD	TRANSACTION	ATM withdrawal amount ≥ 90% of customer’s last 7-day credit.	SYSTEM	2026-02-23 14:06:09.646608
16	ATM_NIGHT_WITHDRAWAL_HIGH_RISK	ATM Night Withdrawal High Risk	FRAUD	TRANSACTION	High value ATM withdrawal during high-risk night window.	SYSTEM	2026-02-23 14:16:27.223599
17	ATM_NEW_CARD_SPIKE	ATM New Card Usage Spike	FRAUD	TRANSACTION	Newly issued card with aggressive ATM usage.	SYSTEM	2026-02-23 14:20:35.589862
18	ATM_FIRST_INTERNATIONAL_USAGE	ATM First International Usage	FRAUD	TRANSACTION	First international ATM transaction on card within 30 days.	SYSTEM	2026-02-23 14:23:20.735811
19	ATM_DECLINE_SUCCESS_PATTERN	ATM Decline Success Pattern	FRAUD	TRANSACTION	Multiple ATM declines followed by successful withdrawal within 15 minutes.	SYSTEM	2026-02-23 14:27:16.726439
20	BIN_FRAUD_RATE_SPIKE	BIN Fraud Rate Spike Detection	FRAUD	TRANSACTION	Detects abnormal increase in BIN-level fraud rate compared to baseline.	SYSTEM	2026-02-23 15:17:55.559105
21	BIN_HIGH_RISK_MCC_CLUSTER	BIN High Risk MCC Fraud Cluster	FRAUD	TRANSACTION	Fraud transactions concentrated in high-risk MCC categories under same BIN.	SYSTEM	2026-02-23 15:21:06.38841
22	BIN_NEW_CARD_FRAUD_SPIKE	BIN New Card Fraud Spike	FRAUD	TRANSACTION	Detects fraud spike among newly issued cards under the same BIN.	SYSTEM	2026-02-23 15:23:12.035277
23	BIN_CHARGEBACK_SPIKE	BIN Chargeback Spike Detection	FRAUD	TRANSACTION	Detects abnormal surge in BIN-level chargeback ratio.	SYSTEM	2026-02-23 15:24:26.385287
24	NETWORK_FRAUD_RATIO_SPIKE	Network Fraud Ratio Spike Detection	FRAUD	TRANSACTION	Detects abnormal increase in overall network fraud ratio.	SYSTEM	2026-02-23 15:25:49.03774
25	NETWORK_MULTI_COUNTRY_SPIKE	Network Multi-Country Fraud Spike	FRAUD	TRANSACTION	Detects simultaneous fraud surge across multiple countries.	SYSTEM	2026-02-23 15:43:37.201607
26	MERCHANT_FRAUD_SPIKE	Merchant Fraud Spike Detection	FRAUD	TRANSACTION	Detects abnormal fraud ratio at merchant level.	SYSTEM	2026-02-23 15:45:24.972352
27	NETWORK_DECLINE_TO_SUCCESS_PATTERN	Network Decline to Success Conversion Spike	NETWORK_MONITORING	TRANSACTION	High decline to success ratio at network level	SYSTEM	2026-02-24 09:47:09.277364
77	ECOM_HIGH_VALUE_TXN	High-Value ECOM Transaction	FRAUD	TRANSACTION	Detects unusually high-value online purchases.	admin	2026-06-29 03:27:49.58866
78	ECOM_HIGH_VALUE_HIGH_RISK_MCC	ECOM High Value Transaction in High-Risk MCC	FRAUD	TRANSACTION	Detects expensive online transactions in high-risk merchant categories.	admin	2026-06-29 03:27:49.58866
79	ECOM_CARD_TXN_COUNT_BURST	Same Card Repeated ECOM Attempts	FRAUD	TRANSACTION	Detects rapid online usage of the same card in a short window.	admin	2026-06-29 03:27:49.58866
80	ECOM_CARD_SAME_MERCHANT_SAME_AMOUNT_REPEAT	Same Card Same Merchant Same Amount Repeat	FRAUD	TRANSACTION	Detects repeated same-card same-merchant same-amount ECOM attempts.	admin	2026-06-29 03:27:49.58866
81	ECOM_CARD_DECLINES_BEFORE_APPROVAL	Declines Before Approval on Same Card	FRAUD	TRANSACTION	Detects multiple ECOM declines on the same card shortly before an approval.	admin	2026-06-29 03:27:49.58866
82	ECOM_CROSS_BORDER_TXN	ECOM Cross-Border Transaction	FRAUD	TRANSACTION	Detects online transactions whose acquiring country is different from the Kanji domestic country.	admin	2026-06-29 03:27:49.58866
83	ECOM_CROSS_BORDER_HIGH_VALUE	ECOM Cross-Border High Value	FRAUD	TRANSACTION	Detects high-value online transactions originating from outside the Kanji domestic country.	admin	2026-06-29 03:27:49.58866
84	ECOM_HIGH_RISK_COUNTRY	ECOM High-Risk Country	FRAUD	TRANSACTION	Detects online transactions from high-risk acquiring countries.	admin	2026-06-29 03:27:49.58866
85	ECOM_BLOCKED_COUNTRY	ECOM Blocked Country	FRAUD	TRANSACTION	Hard-blocks online transactions from blocked or sanctioned acquiring countries.	admin	2026-06-29 03:27:49.58866
86	ECOM_COUNTRY_CURRENCY_MISMATCH	ECOM Country Currency Mismatch	FRAUD	TRANSACTION	Detects suspicious acquiring-country and transaction-currency combinations in ECOM traffic.	admin	2026-06-29 03:27:49.58866
87	POS_HIGH_VALUE_TXN	High-Value POS Transaction	FRAUD	TRANSACTION	Detects high-value card-present transactions.	admin	2026-06-29 03:27:49.58866
88	POS_FALLBACK_HIGH_VALUE_TXN	Fallback High-Value POS Transaction	FRAUD	TRANSACTION	Detects high-value POS transactions that arrive through fallback entry modes.	admin	2026-06-29 03:27:49.58866
89	POS_MANUAL_ENTRY_TXN	Manual Entry POS Transaction	FRAUD	TRANSACTION	Detects manually keyed card-present transactions.	admin	2026-06-29 03:27:49.58866
90	POS_MANUAL_ENTRY_HIGH_VALUE	Manual Entry High-Value POS Transaction	FRAUD	TRANSACTION	Detects high-value manually keyed POS transactions.	admin	2026-06-29 03:27:49.58866
91	POS_CARD_UNIQUE_TERMINAL_SPRAY	Same Card Across Many POS Terminals	FRAUD	TRANSACTION	Detects one card being used across multiple POS terminals in a short period.	admin	2026-06-29 03:27:49.58866
92	POS_CARD_UNIQUE_MERCHANT_SPRAY	Same Card Across Many POS Merchants	FRAUD	TRANSACTION	Detects one card being used across multiple POS merchants in a short period.	admin	2026-06-29 03:27:49.58866
93	POS_CARD_TERMINAL_REPEAT_ATTEMPTS	Same Card Same Terminal Repeated Attempts	FRAUD	TRANSACTION	Detects repeated same-card attempts on the same POS terminal in a short period.	admin	2026-06-29 03:27:49.58866
94	POS_CARD_TERMINAL_SAME_AMOUNT_REPEAT	Same Card Same Terminal Same Amount Repeat	FRAUD	TRANSACTION	Detects repeated identical same-card same-terminal same-amount POS attempts.	admin	2026-06-29 03:27:49.58866
95	POS_CROSS_BORDER_TXN	POS Cross-Border Transaction	FRAUD	TRANSACTION	Detects card-present transactions whose acquiring country is different from the Kanji domestic country.	admin	2026-06-29 03:27:49.58866
96	POS_CROSS_BORDER_HIGH_VALUE	POS Cross-Border High Value	FRAUD	TRANSACTION	Detects high-value card-present transactions originating from outside the Kanji domestic country.	admin	2026-06-29 03:27:49.58866
\.


--
-- PostgreSQL database dump complete
--

\unrestrict igKPVRMcjPtdT8IZZxp6NwhsQZN9B4sJm4RgiIdiLJVerBj50xUeGHHPl15BrK1

