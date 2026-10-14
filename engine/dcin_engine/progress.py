"""JSON-lines protocol between the engine and the SwiftUI app."""

import json
import sys


def emit(type_: str, **kw) -> None:
    sys.__stdout__.write(json.dumps({"type": type_, **kw}, ensure_ascii=False) + "\n")
    sys.__stdout__.flush()


def progress(stage: str, pct: float, msg: str = "") -> None:
    emit("progress", stage=stage, pct=round(max(0.0, min(100.0, pct)), 1), msg=msg)


def log(msg: str) -> None:
    emit("log", msg=msg)


def done(stage: str, **kw) -> None:
    emit("done", stage=stage, **kw)


def error(msg: str) -> None:
    emit("error", msg=msg)
