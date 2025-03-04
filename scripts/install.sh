#!/bin/bash

# XYZLogSnap 安装脚本
# 用法: curl -sSL https://your-domain.com/install.sh | bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 版本信息
GITHUB_REPO="mkdir700/xyz-logsnap-release"

# 动态获取最新版本
echo -e "${BLUE}获取最新版本...${NC}"
VERSION=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | grep 'tag_name' | sed -E 's/.*"v([^"]+)".*/\1/')

# 检查版本号是否获取成功
if [ -z "$VERSION" ]; then
    echo -e "${RED}无法获取最新版本号，使用默认版本 0.0.1${NC}"
    VERSION="0.0.1"
fi

DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}"

# 临时目录
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# 检测操作系统和架构
detect_os_arch() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  
  case $ARCH in
    x86_64)
      ARCH="amd64"
      ;;
    aarch64|arm64)
      ARCH="arm64"
      ;;
    armv7l)
      ARCH="arm"
      ;;
  esac
  
  echo -e "${BLUE}检测到操作系统: ${OS}, 架构: ${ARCH}${NC}"
}

# 检查依赖
check_dependencies() {
  echo -e "${BLUE}检查依赖...${NC}"
  
  if ! command -v curl &> /dev/null; then
    echo -e "${RED}未找到 curl 命令。请先安装 curl。${NC}"
    exit 1
  fi
  
  if ! command -v unzip &> /dev/null; then
    echo -e "${RED}未找到 unzip 命令。请先安装 unzip。${NC}"
    exit 1
  fi

  if ! command -v file &> /dev/null; then
    echo -e "${YELLOW}未找到 file 命令。将无法验证下载文件类型。${NC}"
  fi
}

# 创建安装目录
create_install_dir() {
  INSTALL_DIR="$HOME/.logsnap"
  BIN_DIR="/usr/local/bin"
  
  echo -e "${BLUE}创建安装目录...${NC}"
  mkdir -p "$INSTALL_DIR"
  
  # 检查是否有写入权限
  if [ ! -w "$BIN_DIR" ]; then
    echo -e "${YELLOW}没有 $BIN_DIR 的写入权限，将安装到 $HOME/.local/bin 目录${NC}"
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
  fi
}

# 下载并安装
download_and_install() {
  PACKAGE_NAME="logsnap-linux-amd64.zip"
  FILENAME="${TMP_DIR}/${PACKAGE_NAME}"
  DOWNLOAD_URL="${DOWNLOAD_URL}/${PACKAGE_NAME}"
  
  echo -e "${BLUE}下载 XYZLogSnap v${VERSION}...${NC}"
  echo -e "从 ${DOWNLOAD_URL} 下载中..."
  
  # 下载文件，最多重试3次
  MAX_RETRIES=3
  RETRY_COUNT=0
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -fsSL "$DOWNLOAD_URL" -o "$FILENAME"; then
      break
    else
      RETRY_COUNT=$((RETRY_COUNT+1))
      if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo -e "${YELLOW}下载失败，正在重试 ($RETRY_COUNT/$MAX_RETRIES)...${NC}"
        sleep 2
      else
        echo -e "${RED}下载失败。请检查网络连接或版本是否存在。${NC}"
        echo -e "${RED}下载URL: ${DOWNLOAD_URL}${NC}"
        exit 1
      fi
    fi
  done
  
  # 验证下载文件
  if command -v file &> /dev/null; then
    if ! file "$FILENAME" | grep -q "Zip archive data"; then
      echo -e "${RED}错误：下载的文件不是有效的ZIP格式${NC}"
      echo -e "${RED}文件类型: $(file "$FILENAME")${NC}"
      exit 1
    fi
  fi
  
  echo -e "${BLUE}解压文件...${NC}"
  if ! unzip -q -o "$FILENAME" -d "$INSTALL_DIR"; then
    echo -e "${RED}解压失败。文件可能已损坏或格式不正确。${NC}"
    exit 1
  fi
  
  echo -e "${BLUE}安装 XYZLogSnap...${NC}"
  # 创建可执行文件的符号链接
  ln -sf "$INSTALL_DIR/logsnap" "$BIN_DIR/logsnap"
}

# 验证安装
verify_installation() {
  echo -e "${BLUE}验证安装...${NC}"
  
  if command -v "$BIN_DIR/logsnap" &> /dev/null; then
    echo -e "${GREEN}XYZLogSnap 已成功安装!${NC}"
    echo -e "\n使用方法示例:"
    echo -e "  ${YELLOW}logsnap collect${NC} - 收集最近30分钟的日志"
    echo -e "  ${YELLOW}logsnap collect -u${NC} - 收集最近30分钟的日志并上传云端"
    echo -e "  ${YELLOW}logsnap collect --time 1h${NC} - 收集最近1小时的日志"
    echo -e "  ${YELLOW}logsnap collect --start-time \"2023-03-01 10:00:00\" --end-time \"2023-03-01 11:00:00\"${NC} - 收集指定时间范围的日志"
  else
    echo -e "${RED}安装似乎失败，请手动检查。${NC}"
    echo -e "${YELLOW}尝试手动运行: ${BIN_DIR}/logsnap --version${NC}"
    exit 1
  fi
}

# 主函数
main() {
  echo -e "${GREEN}=== XYZLogSnap 安装程序 ===${NC}"
  
  check_dependencies
  detect_os_arch
  create_install_dir
  download_and_install
  verify_installation
}

# 执行主函数
main
