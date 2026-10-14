"""s1_train.py를 그대로 실행하되, epoch이 끝날 때마다 'DCIN_EPOCH n'을 출력하는 콜백을 끼워 넣는다.

Lightning의 rich 진행바는 터미널이 아니면 마지막에 한 번만 출력되어 진행률을 알 수 없기 때문.
사용: python s1_wrapper.py --config_file <yaml>   (cwd = GPT-SoVITS 루트)
"""

import os
import runpy
import sys

import pytorch_lightning as pl


class _EpochReporter(pl.Callback):
    def on_train_epoch_end(self, trainer, pl_module):
        print(f"DCIN_EPOCH {trainer.current_epoch + 1}", flush=True)


_orig_init = pl.Trainer.__init__


def _patched_init(self, *args, **kwargs):
    kwargs["callbacks"] = list(kwargs.get("callbacks") or []) + [_EpochReporter()]
    _orig_init(self, *args, **kwargs)


pl.Trainer.__init__ = _patched_init

script = os.path.join(os.getcwd(), "GPT_SoVITS", "s1_train.py")
sys.argv = [script, *sys.argv[1:]]
runpy.run_path(script, run_name="__main__")
