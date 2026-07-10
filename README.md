# 大疆第一代 4G 传图模块 (Baiwang) macOS 免驱上网配置备忘录

## 1. 背景说明

大疆第一代 4G 传图模块（设备代号 `Baiwang`，VID: `0x2ca3`, PID: `0x4006`，内置高通方案）出厂默认工作在 **QMI / RMNET** 模式。该模式在 Linux 和 Android 下可以通过底层驱动调用，但在 macOS 下没有原生驱动支持，插入 Mac 后无法直接作为网卡使用，也无法在 `/dev/` 下生成标准的串口设备。

**解决思路**：
该模块硬件本身支持标准的 **CDC-ECM（USB 以太网控制模型）**。macOS、iPadOS 和 Windows 等主流系统均**原生免驱支持 ECM 协议**。
因此，我们可以通过底层 USB 通信（`libusb` / `pyusb`），绕过操作系统的串口驱动限制，直接向模块的 USB Bulk 端口发送 AT 指令，强制将其切换为 ECM 网卡模式。

---

## 2. 环境准备

需要用到 Python 3 和底层 USB 通信库。

```bash
# 1. 安装 libusb (macOS 依赖)
brew install libusb

# 2. 准备 Python 虚拟环境并安装 pyusb
python3 -m venv venv
source venv/bin/activate
pip install pyusb
```

---

## 3. 核心配置脚本 (`dji_at.py`)

创建一个名为 `dji_at.py` 的 Python 脚本，填入以下代码。该脚本会自动寻找大疆模块，遍历 USB 接口找到可用的 AT 指令通信端点（Endpoints），并发送配置指令。

```python
import usb.core
import usb.util
import time

def find_at_endpoint(dev):
    for cfg in dev:
        for intf in cfg:
            out_ep = None
            in_ep = None
            for ep in intf:
                if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_OUT:
                    out_ep = ep
                elif usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_IN:
                    in_ep = ep
            
            # 如果同时找到了输入和输出端点，尝试探测是否为 AT 端口
            if out_ep and in_ep:
                try:
                    if dev.is_kernel_driver_active(intf.bInterfaceNumber):
                        dev.detach_kernel_driver(intf.bInterfaceNumber)
                except Exception as e:
                    pass
                
                try:
                    # 发送空 AT 测试连通性
                    out_ep.write(b'AT\r\n', timeout=100)
                    time.sleep(0.1)
                    res = in_ep.read(64, timeout=100)
                    if b'OK' in res.tobytes() or b'AT' in res.tobytes():
                        return out_ep, in_ep
                except Exception as e:
                    pass
    return None, None

def main():
    # 通过 VID 和 PID 查找大疆传图模块
    dev = usb.core.find(idVendor=0x2ca3, idProduct=0x4006)
    if dev is None:
        print("未找到大疆 4G 模块，请检查是否已插入。")
        return

    print("已发现大疆 4G 模块 (0x2ca3, 0x4006)")
    
    try:
        dev.set_configuration()
    except Exception as e:
        print("设置 USB 配置失败:", e)

    out_ep, in_ep = find_at_endpoint(dev)
    if not out_ep or not in_ep:
        print("未能找到 AT 指令通信端口。")
        return
        
    print("已成功挂载 AT 指令端口！开始发送配置...")
    
    # 核心指令：切换到 ECM (usbnet=1) 并重启模块 (CFUN=1,1)
    commands = [
        b'AT+QCFG="usbnet",1\r\n',
        b'AT+CFUN=1,1\r\n'
    ]
    
    for cmd in commands:
        print(f"发送 AT 指令: {cmd.decode('utf-8').strip()}")
        out_ep.write(cmd, timeout=1000)
        time.sleep(0.5)
        try:
            res = in_ep.read(64, timeout=1000)
            print("模块响应:", res.tobytes().decode('utf-8', errors='ignore').strip())
        except Exception as e:
            print("读取响应失败或超时:", e)

if __name__ == '__main__':
    main()
```

---

## 4. 执行与验证

在终端中执行刚才的脚本：

```bash
python dji_at.py
```

**预期输出：**
```text
Found DJI Cellular Dongle (0x2ca3, 0x4006)
Found AT command endpoints!
Sending AT command: AT+QCFG="usbnet",1
Response: OK
Sending AT command: AT+CFUN=1,1
Response: AT+QCFG="usbnet",1
```

执行成功后，模块会自动重启（指示灯可能会闪烁或熄灭再亮）。等待大约 **15-30秒**，打开 macOS 的 **系统设置 -> 网络**：
你会看到网络列表中新增了一个名为 **`Baiwang`** 的有线网络接口，并且状态显示为“已连接”。

> 提示：**一次配置，终身有效**。AT 配置已经写入模块芯片底层。你现在可以把这个大疆模块拔下来，插到任何一台 Mac、iPad（Type-C 接口）或 Android 手机上，它们都会立刻将其识别为免驱的有线网卡，即插即用！
# DJI-4G-Dongle-macOS-Config
