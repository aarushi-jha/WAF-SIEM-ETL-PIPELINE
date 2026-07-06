# Custom SIEM Pipeline & WAF Deployment Lab

## Objective
The goal of this project was to deploy a local SOC environment using **Chaitin SafeLine WAF** and **Splunk Enterprise** to detect and analyze OWASP Top 10 web vulnerabilities. 

## The Challenge
SafeLine WAF's Community Edition intentionally disables standard syslog forwarding, keeping event logs locked inside a local PostgreSQL Docker container to gatekeep SIEM integration behind a premium license. 

## The Solution
Instead of upgrading or switching tools, I engineered a custom ETL (Extract, Transform, Load) pipeline to bypass the UI constraint:
1. **Breached the Backend:** Dumped Docker `.env` secrets to extract the hardcoded database credentials.
2. **Mapped the Schema:** Explored the internal PostgreSQL database to locate the isolated metadata and payload tables.
3. **Automated Extraction:** Wrote a bash script (`etl_extract.sh`) using a native SQL join to format the raw threat telemetry into sterile JSON and pipe it to the host filesystem.
4. **SIEM Ingestion:** Ingested the custom JSON feed into Splunk and built a real-time threat intelligence dashboard using SPL.

## Dashboard Visualization
![SOC Dashboard](images/your-dashboard-screenshot.png)

## Splunk SPL Queries Used
**Triggered WAF Rules (Pie Chart):**
\`source="/tmp/safeline.log" | spath | stats count by rule_id\`

**Top Attacker IPs (Bar Chart):**
\`source="/tmp/safeline.log" | spath | stats count by src_ip\`

**Live Threat Feed (Data Table):**
\`source="/tmp/safeline.log" | spath | table timestamp, src_ip, method, url_path, rule_id, payload\`

## Attacks Simulated
Weaponized and executed the following payloads against the infrastructure:
* SQL Injection (`\' OR 1=1 --`)
* OS Command Injection (Shellshock)
* SSRF (Metadata API manipulation)
* Log4j / JNDI Lookups
