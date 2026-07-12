#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "    大疆第一代 4G 传图模块 (Baiwang) 配置工具"
echo "=========================================================="
echo "请选择您要配置的模式："
echo "  1. macOS / iPhone / iPad 上网使用 (ECM模式)"
echo "  2. Windows / Linux 上网使用 (RNDIS模式)"
echo "  3. 恢复官方默认模式 (供大疆无人机/设备使用)"
echo "----------------------------------------------------------"

read -p "请输入选项 [1/2/3]: " OPTION < /dev/tty

if [ "$OPTION" == "1" ]; then
    MODE="mac"
    echo "[*] 您选择了：macOS / iPhone / iPad 上网模式"
elif [ "$OPTION" == "2" ]; then
    MODE="win"
    echo "[*] 您选择了：Windows / Linux 上网模式"
elif [ "$OPTION" == "3" ]; then
    MODE="restore"
    echo "[*] 您选择了：恢复官方默认模式"
else
    echo "[x] 无效选项，脚本退出。"
    exit 1
fi
echo "=========================================================="

OS="$(uname -s)"

# 1. 检查并安装 libusb
if [ "$OS" == "Darwin" ]; then
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
elif [ "$OS" == "Linux" ]; then
    # 尝试在 ldconfig 缓存或 dpkg/rpm 中检测 libusb
    if ! ldconfig -p | grep libusb-1.0 > /dev/null 2>&1 && ! dpkg -l | grep libusb-1.0-0 > /dev/null 2>&1; then
        echo "[-] 未检测到 libusb，正在尝试使用 apt/yum 安装..."
        if command -v apt > /dev/null 2>&1; then
            sudo apt update && sudo apt install -y libusb-1.0-0-dev
        elif command -v yum > /dev/null 2>&1; then
            sudo yum install -y libusbx-devel
        else
            echo "[x] 错误：无法自动安装 libusb，请手动安装 libusb-1.0 库。"
            # 继续尝试，不强制退出，以防其实已经安装但未被检测到
        fi
    else
        echo "[+] 系统依赖项 libusb 已存在。"
    fi
else
    echo "[!] 未知操作系统 $OS，尝试跳过依赖安装继续执行..."
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
echo "[-] 开始连接模块并发送指令..."
echo "----------------------------------------------------------"
python dji_at.py "$MODE"
echo "----------------------------------------------------------"

echo "[+] 配置脚本执行完毕！"
if [ "$MODE" == "restore" ]; then
    echo "[+] 如果上方输出中看到 'Response: OK' 和 'AT+QCFG=\"usbnet\",0'，说明恢复成功。"
    echo "[+] 拔插模块即可让大疆设备正常识别使用。"
elif [ "$MODE" == "win" ]; then
    echo "[+] 如果上方输出中看到 'Response: OK' 和 'AT+QCFG=\"usbnet\",3'，说明配置成功。"
    echo "[+] 稍等15-30秒，模块指示灯闪烁重启后，即可在 Windows/Linux 系统网络中看到名为 Baiwang 的新网卡。"
else
    echo "[+] 如果上方输出中看到 'Response: OK' 和 'AT+QCFG=\"usbnet\",1'，说明配置成功。"
    echo "[+] 稍等15-30秒，模块指示灯闪烁重启后，即可在 macOS/iOS 系统网络中看到名为 Baiwang 的新网卡。"
fi
echo "=========================================================="
