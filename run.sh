#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "大疆第一代 4G 传图模块 (Baiwang) macOS 免驱配置一键脚本"
echo "=========================================================="

# 1. 检查并安装 libusb
if ! brew ls --versions libusb > /dev/null 2>&1; then
    echo "[-] 未检测到 libusb，正在尝试使用 Homebrew 安装..."
    if ! command -v brew > /dev/null 2>&1; then
        echo "[x] 错误：未检测到 Homebrew，请先安装 Homebrew (https://brew.sh/)"
        exit 1
    fi
    brew install libusb
else
    echo "[+] 系统依赖项 libusb 已安装。"
fi

# 2. 检查 Python3
if ! command -v python3 > /dev/null 2>&1; then
    echo "[x] 错误：未安装 Python3，请先安装 Python3！"
    exit 1
fi

# 3. 准备虚拟环境
if [ ! -d "venv" ]; then
    echo "[-] 正在创建 Python 虚拟环境..."
    python3 -m venv venv
fi

# 4. 激活虚拟环境并安装依赖
echo "[-] 正在安装必要的 Python 依赖库 (pyusb)..."
source venv/bin/activate
pip install -r requirements.txt --quiet

# 5. 执行核心脚本
echo "[-] 开始连接模块并发送配置指令..."
echo "----------------------------------------------------------"
python dji_at.py
echo "----------------------------------------------------------"

echo "[+] 一键脚本执行完毕！"
echo "[+] 如果上方输出中看到 'Response: OK' 和 'AT+QCFG=\"usbnet\",1'，说明配置成功。"
echo "[+] 稍等15-30秒，模块指示灯闪烁重启后，即可在 '系统设置 -> 网络' 中看到名为 Baiwang 的新网卡。"
echo "=========================================================="
