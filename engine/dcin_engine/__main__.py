"""CLI entry: python -m dcin_engine <command> [--job DIR] ...  (JSON-lines on stdout)"""

import argparse
import sys
import traceback
from pathlib import Path

from .progress import done, error


def main() -> int:
    p = argparse.ArgumentParser(prog="dcin_engine")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("fetch-models")
    sub.add_parser("doctor")
    s = sub.add_parser("separate")
    s.add_argument("--job", required=True, type=Path)
    c = sub.add_parser("convert")
    c.add_argument("--job", required=True, type=Path)
    c.add_argument("--speaker", required=True)
    c.add_argument("--sovits-epochs", type=int, default=8)
    c.add_argument("--gpt-epochs", type=int, default=15)
    c.add_argument("--batch", type=int, default=4)
    t = sub.add_parser("sample")
    t.add_argument("--job", required=True, type=Path)
    e = sub.add_parser("export")
    e.add_argument("--job", required=True, type=Path)
    e.add_argument("--out", required=True, type=Path)
    e.add_argument("--name", default="voice")
    a = p.parse_args()

    try:
        if a.cmd == "fetch-models":
            from . import models

            models.fetch_all()
            done("fetch-models")
        elif a.cmd == "doctor":
            from . import paths

            ok = (paths.ROOT / ".ready").exists() and paths.PRETRAINED_S2G.exists()
            done("doctor", ready=ok, root=str(paths.ROOT))
        elif a.cmd == "separate":
            from . import separate

            done("separate", **separate.run(a.job))
        elif a.cmd == "convert":
            from . import train

            done("convert", **train.run(a.job, a.speaker, a.sovits_epochs, a.gpt_epochs, a.batch))
        elif a.cmd == "sample":
            from . import infer

            done("sample", **infer.run(a.job))
        elif a.cmd == "export":
            from . import export

            done("export", **export.run(a.job, a.out, a.name))
        return 0
    except Exception as ex:
        traceback.print_exc(file=sys.stderr)
        error(str(ex) or ex.__class__.__name__)
        return 1


if __name__ == "__main__":
    sys.exit(main())
