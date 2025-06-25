#!/bin/sh

NEXUS_HOME="/root/.nexus"
BIN_DIR="$NEXUS_HOME/bin"
GREEN='\033[1;32m'
ORANGE='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'  # No Color

# Ensure the $NEXUS_HOME and $BIN_DIR directories exist.
[ -d "$NEXUS_HOME" ] || mkdir -p "$NEXUS_HOME"
[ -d "$BIN_DIR" ] || mkdir -p "$BIN_DIR"

case "$(uname -s)" in
    Linux*)
        PLATFORM="linux"
        case "$(uname -m)" in
            x86_64)
                ARCH="x86_64"
                BINARY_NAME="nexus-network-linux-x86_64"
                ;;
            aarch64|arm64)
                ARCH="arm64"
                BINARY_NAME="nexus-network-linux-arm64"
                ;;
            *)
                echo "${RED}Unsupported architecture: $(uname -m)${NC}"
                echo "Please build from source:"
                echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
                echo "  cd nexus-cli/clients/cli"
                echo "  cargo build --release"
                exit 1
                ;;
        esac
        ;;
    Darwin*)
        PLATFORM="macos"
        case "$(uname -m)" in
            x86_64)
                ARCH="x86_64"
                BINARY_NAME="nexus-network-macos-x86_64"
                echo "${ORANGE}Note: You are running on an Intel Mac.${NC}"
                ;;
            arm64)
                ARCH="arm64"
                BINARY_NAME="nexus-network-macos-arm64"
                echo "${ORANGE}Note: You are running on an Apple Silicon Mac (M1/M2/M3).${NC}"
                ;;
            *)
                echo "${RED}Unsupported architecture: $(uname -m)${NC}"
                echo "Please build from source:"
                echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
                echo "  cd nexus-cli/clients/cli"
                echo "  cargo build --release"
                exit 1
                ;;
        esac
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows"
        case "$(uname -m)" in
            x86_64)
                ARCH="x86_64"
                BINARY_NAME="nexus-network-windows-x86_64.exe"
                ;;
            *)
                echo "${RED}Unsupported architecture: $(uname -m)${NC}"
                echo "Please build from source:"
                echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
                echo "  cd nexus-cli/clients/cli"
                echo "  cargo build --release"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "${RED}Unsupported platform: $(uname -s)${NC}"
        echo "Please build from source:"
        echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
        echo "  cd nexus-cli/clients/cli"
        echo "  cargo build --release"
        exit 1
        ;;
esac

LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases/latest |
    grep "browser_download_url" |
    grep "$BINARY_NAME\"" |       # Match exact file name (not .sha256)
    cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
    echo "${RED}Could not find a precompiled binary for $PLATFORM-$ARCH${NC}"
    echo "Please build from source:"
    echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
    echo "  cd nexus-cli/clients/cli"
    echo "  cargo build --release"
    exit 1
fi

echo "Downloading latest release for $PLATFORM-$ARCH..."
curl -L -o "$BIN_DIR/nexus-network" "$LATEST_RELEASE_URL"
chmod +x "$BIN_DIR/nexus-network"

echo ""
echo "${GREEN}Installation complete!${NC}"

if ! command -v screen >/dev/null 2>&1; then
  echo "📦正在安装screen..."
  sudo apt update && sudo apt install screen -y
fi

for NODE_ID in "$@"; do
  SCREEN_NAME="ns_${NODE_ID}"

  echo "👉 处理节点 $NODE_ID ..."

  # 如果会话已存在，则先杀掉
  if screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo "⚠️ 发现已有会话 '$SCREEN_NAME'，正在关闭..."
    screen -S "$SCREEN_NAME" -X quit
    sleep 1  # 给 screen 一点时间完全关闭
  fi

  # 启动新的 screen 会话
  echo "🚀 启动新的 screen 会话 '$SCREEN_NAME'..."
  screen -dmS "$SCREEN_NAME" "$BIN_DIR/nexus-network" start --node-id "$NODE_ID"

  # 检查是否成功
  if screen -list | grep -q "\.${SCREEN_NAME}"; then
    echo "✅ '$SCREEN_NAME' 启动成功！你可以使用以下命令进入会话："
    echo "    screen -r $SCREEN_NAME"
  else
    echo "❌ 启动 '$SCREEN_NAME' 失败，请检查 BINARY_PATH 和节点参数。"
  fi

  echo ""
done
