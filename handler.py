"""RunPod の GitHub 連携が要求する handler ファイル。

実際の処理は、ベースイメージ（runpod/worker-comfyui）に入っている公式の /handler.py が行う。
コンテナは公式どおり /start.sh で起動し（ComfyUI 起動 → /handler.py）、このファイルは使われない。
単体で実行された場合も、公式の handler 関数をそのまま使って起動する。
"""

import importlib.util

import runpod

_spec = importlib.util.spec_from_file_location("comfy_worker_handler", "/handler.py")
_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_module)

handler = _module.handler

if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
