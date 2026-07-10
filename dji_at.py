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
            
            if out_ep and in_ep:
                try:
                    if dev.is_kernel_driver_active(intf.bInterfaceNumber):
                        dev.detach_kernel_driver(intf.bInterfaceNumber)
                except Exception as e:
                    pass
                
                try:
                    # Try sending AT
                    out_ep.write(b'AT\r\n', timeout=100)
                    time.sleep(0.1)
                    res = in_ep.read(64, timeout=100)
                    if b'OK' in res.tobytes() or b'AT' in res.tobytes():
                        return out_ep, in_ep
                except Exception as e:
                    pass
    return None, None

def main():
    dev = usb.core.find(idVendor=0x2ca3, idProduct=0x4006)
    if dev is None:
        print("DJI Dongle not found.")
        return

    print("Found DJI Cellular Dongle (0x2ca3, 0x4006)")
    
    try:
        dev.set_configuration()
    except Exception as e:
        print("Could not set configuration:", e)

    out_ep, in_ep = find_at_endpoint(dev)
    if not out_ep or not in_ep:
        print("Could not find AT command endpoints.")
        return
        
    print("Found AT command endpoints!")
    
    commands = [
        b'AT+QCFG="usbnet",1\r\n',
        b'AT+CFUN=1,1\r\n'
    ]
    
    for cmd in commands:
        print(f"Sending AT command: {cmd.decode('utf-8').strip()}")
        out_ep.write(cmd, timeout=1000)
        time.sleep(0.5)
        try:
            res = in_ep.read(64, timeout=1000)
            print("Response:", res.tobytes().decode('utf-8', errors='ignore').strip())
        except Exception as e:
            print("No response or error:", e)

if __name__ == '__main__':
    main()
