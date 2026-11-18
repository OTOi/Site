# RunPod Serverless 用: Qwen-Image 2.1（Turbo, int8）画像編集ワーカー
#
# 公式 ComfyUI ワーカー（runpod-workers/worker-comfyui）の base イメージを元に、
#   1. ComfyUI を Qwen-Image 2.1 対応版（v0.45.0）へ入れ替え
#   2. Qwen-Image 2.1 のモデルファイルをイメージに同梱
# する。モデル同梱なので、RunPod 側でネットワークボリュームやモデル配置の作業は不要。
#
# アプリ側の対応プリセット: モデル編集 →「RunPod ComfyUI…」→「Qwen-Image 2.1 編集（自前イメージ）」

FROM runpod/worker-comfyui:5.11.0-base

ARG COMFYUI_VERSION=0.45.0

# --- 1. ComfyUI を入れ替える ---------------------------------------------------
# base イメージの ComfyUI（0.34.0）は Qwen-Image 2.1 のノード（TextEncodeQwenImage21 など）を持たない。
# 旧版のファイルが残らないよう丸ごと入れ替え、ネットワークボリューム設定とカスタムノードだけ引き継ぐ。
RUN set -eux; \
    mv /comfyui /comfyui-old; \
    git clone --depth 1 --branch "v${COMFYUI_VERSION}" https://github.com/comfyanonymous/ComfyUI.git /comfyui; \
    cp -a /comfyui-old/extra_model_paths.yaml /comfyui/; \
    rm -rf /comfyui/custom_nodes; \
    cp -a /comfyui-old/custom_nodes /comfyui/custom_nodes; \
    rm -rf /comfyui-old

# 新しい ComfyUI の依存を、ワーカーが起動に使う /opt/venv へ入れる。
# torch は base イメージの cu128 版を維持し、transformers / huggingface-hub は公式ワーカーと同じ上限を付ける。
RUN uv pip install -r /comfyui/requirements.txt \
    && for r in /comfyui/custom_nodes/*/requirements.txt; do \
         [ -f "$r" ] && uv pip install -r "$r" || true; \
       done \
    && uv pip install "transformers>=4.50.3,<5" "huggingface-hub<1.0"

# 起動確認（GPUなしでノードの読み込みまで通るか）。ここで落ちればビルド失敗になる。
RUN cd /comfyui && timeout 300 python main.py --quick-test-for-ci --cpu

# --- 2. モデルを同梱する -------------------------------------------------------
# Comfy-Org/Qwen-Image-2.1 の公式テンプレート（Turbo 画像編集）と同じファイル。合計 十数GB。
RUN comfy model download \
      --url https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_turbo_int8_convrot.safetensors \
      --relative-path models/diffusion_models --filename qwen_image_2.1_turbo_int8_convrot.safetensors \
    && comfy model download \
      --url https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors \
      --relative-path models/text_encoders --filename qwen3vl_8b_int8_convrot.safetensors \
    && comfy model download \
      --url https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors \
      --relative-path models/vae --filename qwen_image_2.1_vae_bf16.safetensors

CMD ["/start.sh"]
