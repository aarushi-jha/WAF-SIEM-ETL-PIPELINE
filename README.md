# WAF to SIEM Pipeline: Defensive Infrastructure & Threat Telemetry Lab

## Objective
Architected a local Security Operations Center (SOC) lab to deploy defensive web infrastructure, execute weaponized payloads, and engineer a custom Extract, Transform, Load (ETL) pipeline to feed real-time threat intelligence into a SIEM. 

## The Challenge: Vendor Restrictions
The environment utilized **Chaitin SafeLine WAF** to protect local web servers. However, SafeLine's Community Edition deliberately disables standard syslog forwarding. Event logs are locked inside an isolated PostgreSQL Docker container to gatekeep SIEM integration behind a premium enterprise license.

## The Solution: Custom Engineering
Instead of switching tools or paying for a license, I built a bespoke data extraction pipeline to bypass the UI constraint, dump the database, and stream the telemetry directly into **Splunk Enterprise**.

---

## Phase 1: Defensive Infrastructure & Target Setup
* **Storage Provisioning:** Carved out a dedicated partition on the host drive to natively isolate the SOC lab environment and manage Docker storage limits.
* **Target Environment:** Spun up **OWASP Juice Shop** in a container to act as the deliberately vulnerable primary target web application.
* **Reverse Proxy:** Deployed SafeLine WAF via Docker to sit directly in front of Juice Shop, acting as the first line of defense to inspect and route all incoming HTTP/HTTPS traffic.
* **Rule Configuration:** Tuned WAF semantic analysis and pattern matching to intercept and drop malicious requests before they could reach the vulnerable application layer.

<img width="1340" height="1156" alt="WhatsApp Image 2026-07-03 at 11 15 06" src="https://github.com/user-attachments/assets/e85a7f0e-aad7-40f9-9c1c-93e188af64c7" />


<img width="1600" height="738" alt="image" src="https://github.com/user-attachments/assets/22bdbbe0-4f11-4462-bb30-afc2c5cfddc0" />

## Phase 2: Attack Simulation
Weaponized and executed a series of payloads from a Kali Linux host against the proxy to validate block-rules and generate active threat telemetry:
* **SQL Injection:** `\' OR 1=1 --`
* **OS Command Injection:** Shellshock variations
* **SSRF:** Metadata API manipulation
* **Log4j / JNDI Lookups**
* **Polyglot XSS:** Multi-context bypass payload: `'">><script>alert('XSS')</script><svg/onload=alert('XSS')>`

## Phase 3: The Data Engineering Bypass
To extract the generated threat logs out of the WAF and into Splunk:
1. **Breached the Backend:** Interrogated the Docker host environment and dumped `.env` secrets to extract the hardcoded PostgreSQL database credentials.
2. **Mapped the Schema:** Dropped into the container shell to map the internal schema, identifying that metadata and payload strings were isolated in separate tables (`mgt_detect_log_basic` and `mgt_detect_log_detail`).
3. **Automated Extraction:** Engineered a Bash script (`etl_extract.sh`) utilizing a native SQL join to merge the tables, format the raw threat telemetry into sterile JSON, and pipe it continuously to the host filesystem.

## Phase 4: SIEM Ingestion & Visualization
* Ingested the custom JSON feed into Splunk.
* Built a real-time SOC dashboard to visualize the threat landscape, utilizing SPL for data parsing and threat hunting.

### Dashboard Visualizations
<img width="1980" height="1557" alt="WAF Threat Intelligence" src="https://github.com/user-attachments/assets/1ae6fbd1-b4d0-448c-a142-2f88960a1c51" />
<img width="927" height="369" alt="Triggered WAF Rules Panel 1" src="https://github.com/user-attachments/assets/ecac7be8-43cf-480e-9ac6-b44caa6186d3" />
<img width="1029" height="369" alt="Top Attacker IPs Panel 2" src="https://github.com/user-attachments/assets/a45eda52-bdc1-47ca-b068-72d8e39a656b" />
<img width="1968" height="985" alt="Live Threat Feed Panel 3" src="https://github.com/user-attachments/assets/e7e3d34e-7171-4462-bd4e-f999de6e768d" />
SPL Search History
<img width="2846" height="1364" alt="image" src="https://github.com/user-attachments/assets/355197cc-12a0-4c34-9db8-e77ae6a7ebd6" />


### Core SPL Queries Used
**Triggered WAF Rules (Pie Chart):**
`source="/tmp/safeline.log" | spath | stats count by rule_id`

**Top Attacker IPs (Bar Chart):**
`source="/tmp/safeline.log" | spath | stats count by src_ip`

**Live Threat Feed (Data Table):**
`source="/tmp/safeline.log" | spath | table timestamp, src_ip, method, url_path, rule_id, payload`

## Tech Stack
* **Infrastructure:** Docker, Linux (Kali)
* **Security:** Chaitin SafeLine WAF, Splunk Enterprise
* **Data/Scripting:** PostgreSQL, Bash, SQL, SPL
