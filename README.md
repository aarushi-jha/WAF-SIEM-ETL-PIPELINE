# WAF to SIEM Pipeline: Defensive Infrastructure & Threat Telemetry Lab

## Executive Summary
Architected a local Security Operations Center (SOC) lab to deploy defensive web infrastructure, execute weaponized payloads, and engineer a custom Extract, Transform, Load (ETL) pipeline to feed real-time threat intelligence into a SIEM.

## The Challenge: Vendor Enterprise Paywalls
The environment deployed **Chaitin SafeLine WAF** to protect local web applications. However, SafeLine's Community Edition deliberately disables standard syslog forwarding, locking event logs inside an isolated PostgreSQL Docker container to gatekeep SIEM integration behind an enterprise license.

## The Engineering Solution
Rather than switching tools or purchasing an enterprise license, I engineered a bespoke data extraction pipeline to bypass the UI constraint, query the underlying PostgreSQL database, and stream raw telemetry directly into **Splunk Enterprise**.

---

## Architecture & Deployment

### Phase 1: Defensive Infrastructure & Target Setup
* **Storage Isolation:** Provisioned a dedicated partition on the host drive to isolate the lab environment and enforce strict Docker volume resource limits.
* **Vulnerable Target:** Deployed **OWASP Juice Shop** in a Docker container as the primary target web application.
* **Reverse Proxy WAF:** Configured SafeLine WAF via Docker as a reverse proxy sitting directly in front of Juice Shop to inspect and filter all incoming HTTP/HTTPS traffic.
* **Rule Engine Tuning:** Configured semantic analysis and pattern-matching rules to drop malicious HTTP requests before reaching the application layer.

#### Interface & Pipeline Evidence
![SafeLine Dashboard Overview](https://github.com/user-attachments/assets/e85a7f0e-aad7-40f9-9c1c-93e188af64c7)
![Rule Engine Configurations](https://github.com/user-attachments/assets/c1fc568f-c6c0-4a2b-a1b4-9c35fc66f6f6)
![Interceptor Logs](https://github.com/user-attachments/assets/5a86921d-1ece-4622-b0d1-788be4661559)
![Blocked Requests Detail](https://github.com/user-attachments/assets/03c91f5f-4b3c-4bbc-9618-b80b6780d0a4)
![Juice Shop Target Application](https://github.com/user-attachments/assets/22bdbbe0-4f11-4462-bb30-afc2c5cfddc0)

---

### Phase 2: Attack Simulation
Executed targeted web attack vectors from a Kali Linux host against the reverse proxy to validate detection controls and generate threat logs:

* **SQL Injection (SQLi):** `' OR 1=1 --`
* **OS Command Injection:** Shellshock payload variations
* **Server-Side Request Forgery (SSRF):** Cloud metadata API probes (`169.254.169.254`)
* **Log4j / JNDI Probes:** `${jndi:ldap://...}`
* **Polyglot XSS:** `'"><script>alert('XSS')</script><svg/onload=alert('XSS')>`

---

### Phase 3: The ETL Pipeline Bypass
To extract threat logs from the isolated WAF container into Splunk:

1. **Credential Extraction:** Interrogated the Docker environment variables (`docker inspect`) and extracted the hardcoded PostgreSQL database credentials.
2. **Schema Mapping:** Dropped into the container shell and mapped the database relations. Identified that attack metadata and raw payload strings were separated across `mgt_detect_log_basic` and `mgt_detect_log_detail`.
3. **Automated Pipeline (`etl_extract.sh`):** Authored a Bash ETL script that executes an inner join on the two tables, formats the merged output into clean JSON, and streams it to the host filesystem.

```bash
#!/bin/bash
# Sample query logic inside etl_extract.sh
docker exec -i safeline-postgres psql -U safeline -d safeline -c \
"SELECT json_build_object(
    'timestamp', b.create_time,
    'src_ip', b.src_ip,
    'method', b.http_method,
    'url_path', b.url,
    'rule_id', d.rule_id,
    'payload', d.payload
) FROM mgt_detect_log_basic b 
JOIN mgt_detect_log_detail d ON b.id = d.log_id;" >> /tmp/safeline.log
```

---

### Phase 4: SIEM Ingestion & Analytics

Ingested `/tmp/safeline.log` into Splunk Enterprise and built a SOC monitoring dashboard.

#### SOC Dashboard & Telemetry
![WAF Threat Intelligence Overview](https://github.com/user-attachments/assets/1ae6fbd1-b4d0-448c-a142-2f88960a1c51)
![Triggered WAF Rules Panel](https://github.com/user-attachments/assets/ecac7be8-43cf-480e-9ac6-b44caa6186d3)
![Top Attacker IPs Panel](https://github.com/user-attachments/assets/a45eda52-bdc1-47ca-b068-72d8e39a656b)
![Live Threat Feed Panel](https://github.com/user-attachments/assets/e7e3d34e-7171-4462-bd4e-f999de6e768d)
![SPL Search Console](https://github.com/user-attachments/assets/355197cc-12a0-4c34-9db8-e77ae6a7ebd6)

#### Core SPL Queries

* **Triggered WAF Rules (Pie Chart):**
  ```spl
  source="/tmp/safeline.log" | spath | stats count by rule_id
  ```

* **Top Attacker IPs (Bar Chart):**
  ```spl
  source="/tmp/safeline.log" | spath | stats count by src_ip
  ```

* **Live Threat Feed Table:**
  ```spl
  source="/tmp/safeline.log" | spath | table timestamp, src_ip, method, url_path, rule_id, payload
  ```

---

## Tech Stack
* **Infrastructure:** Docker, Linux (Kali)
* **Defensive Security:** Chaitin SafeLine WAF, Splunk Enterprise
* **Data & Scripting:** PostgreSQL, Bash, SQL, SPL
