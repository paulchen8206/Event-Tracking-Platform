from __future__ import annotations

import os
import shlex
import subprocess
from dataclasses import dataclass
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


@dataclass(frozen=True)
class SparkJobDefinition:
    command_env_var: str


class SparkRunRequest(BaseModel):
    arguments: list[str] = Field(default_factory=list)


class DbtRunRequest(BaseModel):
    command: str
    select: Optional[str] = None
    target: Optional[str] = None
    project_dir: Optional[str] = None
    profiles_dir: Optional[str] = None


class CommandResult(BaseModel):
    ok: bool
    command: str
    return_code: int
    stdout: str
    stderr: str


app = FastAPI(title="orchestration-api", version="0.1.0")


SPARK_JOB_DEFINITIONS: dict[str, SparkJobDefinition] = {
    "canonical_lakehouse_refresh": SparkJobDefinition("SPARK_APP_CANONICAL_COMMAND"),
    "operational_mail_tracking_projection": SparkJobDefinition("SPARK_APP_OPS_COMMAND"),
}


def _env(name: str, default: str) -> str:
    value = os.getenv(name, "").strip()
    return value or default


def _run_command(command_tokens: list[str], cwd: Optional[str] = None) -> CommandResult:
    result = subprocess.run(
        command_tokens,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )

    return CommandResult(
        ok=result.returncode == 0,
        command=" ".join(command_tokens),
        return_code=result.returncode,
        stdout=result.stdout,
        stderr=result.stderr,
    )


def _resolve_spark_command(job_id: str, arguments: list[str]) -> list[str]:
    definition = SPARK_JOB_DEFINITIONS.get(job_id)
    if definition is None:
        raise HTTPException(status_code=404, detail=f"Unknown spark job id: {job_id}")

    raw_command = _env(definition.command_env_var, "")
    if not raw_command:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Missing spark command configuration. Set {definition.command_env_var} "
                f"for job_id={job_id}."
            ),
        )

    command_tokens = shlex.split(raw_command)
    command_tokens.extend(arguments)
    return command_tokens


def _resolve_dbt_command(request: DbtRunRequest) -> tuple[list[str], str]:
    allowed = {"deps", "debug", "build"}
    if request.command not in allowed:
        raise HTTPException(status_code=400, detail=f"Unsupported dbt command: {request.command}")

    project_dir = request.project_dir or _env("DBT_PROJECT_DIR", "/opt/airflow/platform/dbt")
    profiles_dir = request.profiles_dir or _env("DBT_PROFILES_DIR", "/opt/airflow/platform/dbt")
    target = request.target or _env("DBT_TARGET", "dev")

    command_tokens = [
        "dbt",
        request.command,
        "--profiles-dir",
        profiles_dir,
        "--target",
        target,
    ]

    if request.command == "build" and request.select:
        command_tokens.extend(["--select", request.select])

    return command_tokens, project_dir


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/spark/jobs/{job_id}/runs", response_model=CommandResult)
def run_spark_job(job_id: str, request: SparkRunRequest) -> CommandResult:
    command_tokens = _resolve_spark_command(job_id, request.arguments)
    result = _run_command(command_tokens)
    if not result.ok:
        raise HTTPException(status_code=500, detail=result.model_dump())
    return result


@app.post("/v1/dbt/runs", response_model=CommandResult)
def run_dbt(request: DbtRunRequest) -> CommandResult:
    command_tokens, project_dir = _resolve_dbt_command(request)
    result = _run_command(command_tokens, cwd=project_dir)
    if not result.ok:
        raise HTTPException(status_code=500, detail=result.model_dump())
    return result
