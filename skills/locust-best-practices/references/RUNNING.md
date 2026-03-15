# Locust — Running Modes: Headless, Distributed & Logging

## When to load this file

Load when the user asks about: CI/CD integration, headless mode, exit codes, distributed
testing, master/worker setup, Docker, multiple cores, logging to file, or custom log levels.

---

## 1. Headless Mode (no Web UI)

Use `--headless` to run Locust in CI/CD pipelines or automated environments.

```bash
# Basic headless run
locust -f locustfile.py --headless \
  -u 100 -r 10 -t 5m \
  --host https://api.example.com

# With HTML report and CSV output
locust -f locustfile.py --headless \
  -u 100 -r 10 -t 5m \
  --host https://api.example.com \
  --html report.html \
  --csv results \
  --only-summary
```

**Key headless flags:**

| Flag | Description |
|---|---|
| `--headless` | Disable web UI, start test immediately |
| `-u` | Peak concurrent users |
| `-r` | Spawn rate (users/second) |
| `-t` | Run time (e.g. `30s`, `5m`, `1h30m`) |
| `-s / --stop-timeout` | Seconds to wait for VUs to finish current task before stopping |
| `--only-summary` | Suppress per-interval stats — print only final summary |
| `--html <path>` | Generate HTML report at path |
| `--csv <prefix>` | Generate CSV files: `<prefix>_stats.csv`, `<prefix>_failures.csv` |

**Interactive adjustments during headless run:**
- `w` / `W` — add 1 or 10 users
- `s` / `S` — remove 1 or 10 users

---

## 2. CI/CD Integration — Controlling Exit Code

By default Locust exits with code 0 even if thresholds are breached. To fail a CI build
on SLA violations, hook into the `quitting` event:

```python
from locust import events

@events.quitting.add_listener
def assert_stats(environment, **kwargs):
    """Fail CI if any SLA is breached. Set exit code before process exits."""
    stats = environment.stats.total

    if stats.fail_ratio > 0.01:
        environment.process_exit_code = 1
        print(f"FAIL: error rate {stats.fail_ratio:.1%} > 1%")

    elif stats.get_response_time_percentile(0.95) > 800:
        environment.process_exit_code = 1
        print(f"FAIL: p95 {stats.get_response_time_percentile(0.95)}ms > 800ms")

    elif stats.avg_response_time > 200:
        environment.process_exit_code = 1
        print(f"FAIL: avg response {stats.avg_response_time:.0f}ms > 200ms")

    else:
        environment.process_exit_code = 0
        print("PASS: all SLAs met")
```

**GitHub Actions example:**

```yaml
- name: Run load test
  run: |
    locust -f locustfile.py --headless \
      -u 50 -r 5 -t 5m \
      --host ${{ secrets.TARGET_HOST }} \
      --html report.html \
      --csv results
  env:
    TEST_USER: ${{ secrets.TEST_USER }}
    TEST_PASSWORD: ${{ secrets.TEST_PASSWORD }}

- name: Upload report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: locust-report
    path: |
      report.html
      results_stats.csv
      results_failures.csv
```

**`stats.total` attributes available for SLA checks:**

| Attribute | Description |
|---|---|
| `fail_ratio` | Float 0–1: proportion of failed requests |
| `avg_response_time` | Average response time in ms |
| `get_response_time_percentile(0.95)` | p95 in ms |
| `get_response_time_percentile(0.99)` | p99 in ms |
| `num_failures` | Total failure count |
| `num_requests` | Total request count |

---

## 3. Distributed Mode

Use distributed mode when a single process cannot generate enough load (CPU-bound at the
test runner, not the target). Each worker runs one process; each process can handle
thousands of VUs via gevent.

### Single machine — multiple cores

```bash
# Auto-detect and use all available CPU cores
locust -f locustfile.py --processes -1

# Explicit core count
locust -f locustfile.py --processes 4
```

### Multiple machines

**On the master machine:**
```bash
locust -f locustfile.py --master --expect-workers 4
```

**On each worker machine:**
```bash
# -f - tells the worker to receive the locustfile from the master
locust -f - --worker --master-host <master-ip> --processes 4
```

**Headless distributed run:**
```bash
# Master
locust -f locustfile.py --master --headless \
  -u 1000 -r 50 -t 10m \
  --expect-workers 4 \
  --host https://api.example.com

# Each worker (run on separate machines)
locust -f - --worker --master-host 10.0.0.1 --processes 4
```

**Key distributed flags:**

| Flag | Used on | Description |
|---|---|---|
| `--master` | Master | Run as coordinator |
| `--worker` | Worker | Run as executor |
| `--master-host` | Worker | Master IP/hostname (default: localhost) |
| `--master-port` | Both | Communication port (default: 5557) |
| `--expect-workers N` | Master | Wait for N workers before starting headless test |
| `--processes N` | Both | Spawn N worker processes on same machine (`-1` = all cores) |

**Rules for distributed mode:**
- Python's GIL limits one core per process — run one worker process per CPU core.
- Use `-f -` on workers to receive the locustfile from the master automatically.
- Total VUs are distributed evenly across all workers by the master.
- All workers must be able to reach the master on port 5557 (check firewall rules).

---

## 4. Logging

Locust uses Python's standard `logging` module. Use it freely inside tasks:

```python
import logging

class MyUser(HttpUser):
    @task
    def get_data(self):
        with self.client.get("/data", catch_response=True) as response:
            if response.status_code != 200:
                logging.warning(f"Unexpected status: {response.status_code}")
                response.failure(f"Status {response.status_code}")
```

**CLI logging flags:**

| Flag | Description |
|---|---|
| `--loglevel / -L` | Log level: DEBUG, INFO, WARNING, ERROR, CRITICAL (default: INFO) |
| `--logfile` | Write logs to file (stats still print to console regardless) |
| `--skip-log-setup` | Disable Locust's log config — use when you need full control |

**Important:** `locust.stats_logger` (periodic stats output) always prints to console
even when `--logfile` is set — it is not captured in the log file.

**Example — debug mode with file output:**
```bash
locust -f locustfile.py --headless -u 10 -r 1 -t 1m \
  --host https://api.example.com \
  --loglevel DEBUG \
  --logfile locust-debug.log
```

**Structured logging for CI:**
```python
import logging
import json

logger = logging.getLogger("load-test")

class ApiUser(HttpUser):
    @task
    def get_items(self):
        with self.client.get("/items", catch_response=True) as response:
            if response.status_code != 200:
                logger.error(json.dumps({
                    "event": "request_failed",
                    "url": "/items",
                    "status": response.status_code,
                    "user_id": self.environment.runner.user_count,
                }))
                response.failure(f"Status {response.status_code}")
```
