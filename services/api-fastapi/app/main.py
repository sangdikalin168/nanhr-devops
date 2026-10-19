import os

from fastapi import FastAPI

app = FastAPI(title="nanhr-api-fastapi", root_path=os.getenv("ROOT_PATH", ""))


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "api-fastapi", "version": os.getenv("APP_VERSION", "dev")}


# Stand-in for the real payslip/report endpoints.
@app.get("/reports/summary")
def report_summary() -> dict:
    return {"employees": 0, "overtimeHours": 0, "pendingApprovals": 0}
