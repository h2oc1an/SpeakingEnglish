#!/bin/bash
# 下载 WhisperKit CoreML 模型到 Resources/WhisperModels/
# 由于 HuggingFace 在大陆可能无法访问，可以使用镜像或代理

set -e

MODEL_VARIANT=${1:-tiny}  # 默认使用 tiny 模型，可选: tiny, base, small, medium
TARGET_DIR="Resources/WhisperModels"
REPO="argmaxinc/whisperkit-coreml"

echo "下载 WhisperKit $MODEL_VARIANT 模型到 $TARGET_DIR..."

# 创建目录
mkdir -p "$TARGET_DIR"

# 如果有 VPN/代理，设置 HUGGINGFACE_HUB_TOKEN 环境变量
# export HUGGINGFACE_HUB_TOKEN=your_token_here

# 尝试使用 huggingface-cli 下载
if command -v huggingface-cli &> /dev/null; then
    echo "使用 huggingface-cli 下载..."
    huggingface-cli download "$REPO" "$MODEL_VARIANT*" --local-dir "$TARGET_DIR" --local-dir-use-symlinks False
else
    echo "huggingface-cli 未安装，尝试直接下载..."
    # 尝试直接下载 (可能需要代理)
    BASE_URL="https://huggingface.co/$REPO/resolve/main"

    # 下载模型目录下的所有文件
    for size in "$MODEL_VARIANT"; do
        # 获取文件列表
        FILES=$(curl -s "https://api.github.com/repos/argmaxinc/whisperkit/contents/models?ref=main" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | grep "$MODEL_VARIANT" || true)

        if [ -z "$FILES" ]; then
            echo "无法获取文件列表，请确保网络可访问 HuggingFace"
            echo "或手动下载模型文件到 $TARGET_DIR"
            exit 1
        fi
    done
fi

echo "下载完成！文件列表:"
ls -la "$TARGET_DIR/"

echo ""
echo "注意: WhisperKit 需要以下文件存在:"
echo "  - MelSpectrogram.mlmodelc (或 .mlpackage)"
echo "  - AudioEncoder.mlmodelc (或 .mlpackage)"
echo "  - TextDecoder.mlmodelc (或 .mlpackage)"
