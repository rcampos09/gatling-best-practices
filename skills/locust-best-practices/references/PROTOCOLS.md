# Locust — Non-HTTP Protocols

Locust supports HTTP/HTTPS natively via `HttpUser`. For other protocols, you must
wrap the client library, capture metrics manually, and fire `environment.events.request`.

---

## WebSocket

Use the `websocket-client` library (gevent-compatible):

```bash
pip install websocket-client locust
```

```python
import time
import websocket
from locust import User, task, between, events

class WebSocketClient:
    """Thin wrapper that reports metrics to Locust."""

    def __init__(self, host, environment):
        self.host = host
        self.env = environment
        self.ws = websocket.create_connection(host)

    def send(self, name, payload):
        start = time.time()
        exception = None
        response_length = 0
        try:
            self.ws.send(payload)
            result = self.ws.recv()
            response_length = len(result)
        except Exception as e:
            exception = e
        finally:
            elapsed = int((time.time() - start) * 1000)
            self.env.events.request.fire(
                request_type="WS",
                name=name,
                response_time=elapsed,
                response_length=response_length,
                exception=exception,
            )
        return result

    def close(self):
        self.ws.close()


class WsUser(User):
    abstract = True  # prevents Locust from spawning this class directly

    def on_start(self):
        self.client = WebSocketClient(self.host, self.environment)

    def on_stop(self):
        self.client.close()


class ChatUser(WsUser):
    host = "wss://chat.example.com/ws"
    wait_time = between(1, 3)

    @task
    def send_message(self):
        self.client.send("send_message", '{"text": "hello"}')

    @task
    def ping(self):
        self.client.send("ping", '{"type": "ping"}')
```

**Key rules for WebSocket:**
- Always close the connection in `on_stop()` — leaked connections exhaust server resources.
- Use `abstract = True` on the base user class to prevent accidental direct spawning.
- Track roundtrip time by recording `time.time()` before send and after receive.

---

## gRPC

Use `grpc` with `grpc_gevent` to patch gRPC for gevent compatibility:

```bash
pip install grpcio grpc-gevent locust
```

```python
import grpc
import grpc_gevent
import time
from locust import User, task, between

grpc_gevent.init_gevent()  # must be called before any gRPC imports

import your_service_pb2 as pb2
import your_service_pb2_grpc as pb2_grpc
from grpc_interceptor import ClientInterceptor


class LocustGrpcInterceptor(ClientInterceptor):
    """Intercepts gRPC calls and fires Locust request events."""

    def __init__(self, environment):
        self.env = environment

    def intercept(self, method, request_or_iterator, call_details):
        start = time.time()
        exception = None
        response = None
        try:
            response = method(request_or_iterator, call_details)
        except grpc.RpcError as e:
            exception = e
        finally:
            elapsed = int((time.time() - start) * 1000)
            self.env.events.request.fire(
                request_type="gRPC",
                name=call_details.method,
                response_time=elapsed,
                response_length=0,
                exception=exception,
            )
        return response


class GrpcUser(User):
    abstract = True

    def on_start(self):
        interceptor = LocustGrpcInterceptor(self.environment)
        channel = grpc.intercept_channel(
            grpc.insecure_channel(self.host),
            interceptor,
        )
        self.stub = pb2_grpc.YourServiceStub(channel)


class ApiGrpcUser(GrpcUser):
    host = "localhost:50051"
    wait_time = between(1, 2)

    @task
    def get_user(self):
        self.stub.GetUser(pb2.GetUserRequest(id=1))
```

**Key rules for gRPC:**
- Call `grpc_gevent.init_gevent()` before any other gRPC imports.
- Use an interceptor to capture metrics — do not instrument each stub call manually.
- `response_length` is 0 unless you serialize the response and measure its byte size.

---

## Custom metrics via `events.request.fire()`

Use this to report any custom operation (DB query, queue publish, cache hit) to Locust stats:

```python
import time
from locust import events

def timed_operation(env, name, fn):
    """Utility to wrap any callable and report to Locust."""
    start = time.time()
    exception = None
    result = None
    try:
        result = fn()
    except Exception as e:
        exception = e
        raise
    finally:
        env.events.request.fire(
            request_type="CUSTOM",
            name=name,
            response_time=int((time.time() - start) * 1000),
            response_length=0,
            exception=exception,
        )
    return result
```

**`request.fire()` parameters:**

| Parameter | Type | Description |
|---|---|---|
| `request_type` | str | Label shown in stats table (e.g. `"HTTP"`, `"WS"`, `"gRPC"`) |
| `name` | str | Operation name — group dynamic names with `[id]` convention |
| `response_time` | int | Milliseconds |
| `response_length` | int | Bytes (use 0 if unknown) |
| `exception` | Exception or None | `None` = success; any exception = failure |

---

## Protocol library compatibility

| Library | gevent-compatible | Notes |
|---|---|---|
| `requests` | ✅ Yes | Used by `HttpUser` natively |
| `websocket-client` | ✅ Yes | Recommended for WebSocket |
| `grpcio` + `grpc-gevent` | ✅ With patch | Must call `grpc_gevent.init_gevent()` first |
| `aiohttp` | ❌ No | asyncio-based — not compatible with gevent |
| `httpx` (async) | ❌ No | Use sync mode only |
| `boto3` | ✅ Yes | Works for AWS SDK load testing |
