# Locust — Design Patterns & Project Structure

## When to load this file

Load when the user asks about: folder structure, multi-file locustfiles, shared auth helpers,
multiple user classes, TaskSet vs @task, data factories, modular design, or reusable components.

---

## Project structure for production locustfiles

```
load-tests/
├── locustfile.py          ← entry point — imports and assembles user classes
├── users/
│   ├── __init__.py
│   ├── shop_user.py       ← HttpUser subclass for e-commerce flows
│   └── admin_user.py      ← HttpUser subclass for admin flows
├── tasks/
│   ├── __init__.py
│   ├── catalog.py         ← browsing tasks shared across user types
│   └── checkout.py        ← purchase flow tasks
├── data/
│   ├── users.csv          ← test credentials
│   └── products.json      ← product catalog for parameterization
└── common/
    ├── __init__.py
    ├── auth.py            ← login helpers
    └── data_loader.py     ← CSV/JSON loaders
```

**Rule:** Keep `locustfile.py` thin — it should only import and expose user classes.
All logic lives in `users/`, `tasks/`, and `common/`.

---

## Pattern 1 — Shared auth helper

Extract login logic into a reusable function, not duplicated across user classes:

```python
# common/auth.py
import os

def login(client):
    """Logs in and returns the access token. Raises on failure."""
    with client.post(
        "/auth/login",
        json={
            "username": os.environ["TEST_USER"],
            "password": os.environ["TEST_PASSWORD"],
        },
        catch_response=True,
    ) as response:
        if response.status_code != 200:
            response.failure(f"Login failed: {response.status_code}")
            return None
        return response.json()["access_token"]


# users/shop_user.py
from locust import HttpUser, task, between
from common.auth import login

class ShopUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        self.token = login(self.client)

    def _headers(self):
        return {"Authorization": f"Bearer {self.token}"}
```

---

## Pattern 2 — CSV data loader (module-level, not per-VU)

Load test data once at import time and distribute across VUs using modulo indexing:

```python
# common/data_loader.py
import csv

def load_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


# users/shop_user.py
from locust import HttpUser, task, between
from common.data_loader import load_csv

# Loaded once at module import — shared across all VUs
USERS = load_csv("data/users.csv")

class ShopUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        # Each VU gets a different row using modulo cycling
        user = USERS[self.environment.runner.user_count % len(USERS)]
        self.username = user["username"]
        self.password = user["password"]
```

---

## Pattern 3 — Multiple user classes with population weights

Simulate different user personas in a single test run:

```python
# locustfile.py
from locust import HttpUser, task, between

class BrowserUser(HttpUser):
    """60% of traffic — anonymous browsing."""
    weight = 6
    wait_time = between(2, 5)

    @task
    def browse(self):
        self.client.get("/products")

class AuthenticatedUser(HttpUser):
    """30% — logged-in users browsing their wishlist."""
    weight = 3
    wait_time = between(1, 3)

    def on_start(self):
        # login ...
        pass

    @task
    def view_wishlist(self):
        self.client.get("/wishlist")

class PowerUser(HttpUser):
    """10% — users who frequently purchase."""
    weight = 1
    wait_time = between(1, 2)

    @task
    def checkout(self):
        self.client.post("/checkout", json={"cart_id": 1})
```

**Run command for multiple classes:**
```bash
locust -f locustfile.py --headless -u 100 -r 10 -t 5m --host https://api.example.com
# Locust distributes users by weight automatically: 60 BrowserUser, 30 AuthenticatedUser, 10 PowerUser
```

---

## Pattern 4 — TaskSet for hierarchical flows

Use `TaskSet` only when a user flow has a clear nested structure. For most cases,
plain `@task` methods on `HttpUser` are simpler and preferred.

```python
from locust import HttpUser, TaskSet, task, between

class ForumTasks(TaskSet):
    """Nested task set — user browses the forum section."""

    @task(3)
    def read_thread(self):
        self.client.get("/forum/threads/1")

    @task(1)
    def post_reply(self):
        self.client.post("/forum/threads/1/replies", json={"body": "test"})

    @task(1)
    def exit_forum(self):
        self.interrupt()  # returns control to parent HttpUser


class WebUser(HttpUser):
    wait_time = between(1, 3)
    tasks = [ForumTasks]  # delegate to TaskSet

    @task(5)
    def homepage(self):
        self.client.get("/")
```

**When to use TaskSet vs @task:**

| Use TaskSet when... | Use @task when... |
|---|---|
| Flow has clear nested sections (forum → thread → reply) | Tasks are independent and at the same level |
| You need `interrupt()` to exit a section | Flow is a flat sequence of steps |
| Modeling hierarchical site navigation | Modeling a simple API consumer |

> **Caution:** TaskSet without `interrupt()` will loop forever inside the set.
> Always include an exit task that calls `self.interrupt()`.

---

## Pattern 5 — Environment variable configuration

Never hardcode any URL, credential, or test parameter:

```python
import os
from locust import HttpUser, task, between

# All config from environment — with safe defaults for local dev
TARGET_HOST   = os.environ.get("TARGET_HOST", "http://localhost:8080")
TEST_USER     = os.environ["TEST_USER"]      # required — no default
TEST_PASSWORD = os.environ["TEST_PASSWORD"]  # required — no default
THINK_TIME_MIN = float(os.environ.get("THINK_TIME_MIN", "1"))
THINK_TIME_MAX = float(os.environ.get("THINK_TIME_MAX", "3"))

class ApiUser(HttpUser):
    host = TARGET_HOST
    wait_time = between(THINK_TIME_MIN, THINK_TIME_MAX)
```

**Run with env vars:**
```bash
TARGET_HOST=https://staging.api.com \
TEST_USER=alice \
TEST_PASSWORD=secret \
THINK_TIME_MIN=0.5 \
locust -f locustfile.py --headless -u 50 -r 5 -t 5m
```

---

## Anti-patterns to avoid

| Anti-pattern | Problem | Fix |
|---|---|---|
| Login in `__init__` instead of `on_start` | `__init__` runs before the Locust runner is ready — HTTP client may not be initialized | Always use `on_start` for per-VU setup |
| Global mutable state (shared lists, counters) | Race conditions in gevent — greenlets share memory | Use `self.*` instance attributes or thread-safe queues |
| Importing heavy libraries inside tasks | Imported on every task execution — slows down VUs | Import at module level |
| Hardcoded sleep instead of `wait_time` | Bypasses Locust's wait_time system — harder to control | Use `wait_time = between(min, max)` |
| One massive locustfile > 300 lines | Hard to maintain | Split into `users/`, `tasks/`, `common/` modules |
