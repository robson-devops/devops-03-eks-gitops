import time

from fastapi import FastAPI, Query, Request, Response
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

app = FastAPI(title="demo-api")

REQUESTS = Counter(
    "http_requests_total",
    "Requisições HTTP recebidas",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Latência das requisições HTTP",
    ["method", "path"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    # Rota declarada, não a URL crua: evita uma série por query string.
    route = request.scope.get("route")
    path = route.path if route else "desconhecida"
    if path != "/metrics":
        LATENCY.labels(request.method, path).observe(time.perf_counter() - start)
        REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    return response


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    return {"status": "ready"}


@app.get("/work")
def work(ms: int = Query(default=100, ge=1, le=2000)):
    # Consome CPU pelo tempo pedido; usado para acionar o HPA.
    deadline = time.perf_counter() + ms / 1000
    count = 0
    while time.perf_counter() < deadline:
        count += 1
    return {"ms": ms, "iterations": count}


@app.get("/error")
def error():
    # Sempre 500; usado para acionar o alerta de taxa de erro.
    return JSONResponse(status_code=500, content={"status": "error"})


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)