#!/usr/bin/env python3

"""
reTerminal Multi-Button Handler
- F1 Button: Opens Grafana System Vitals Dashboard
- F2 Button: Opens Home Assistant Overview  
- F3 Button: Opens Pi-hole Dashboard (auto-login)
- O Button (Green Circle): Opens Homepage
Uses the same method as the Seeed examples
"""

import subprocess
import time
import os
import signal
import sys
import logging
from evdev import InputDevice, ecodes

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

class MultiButtonHandler:
    def __init__(self):
        self.device_path = None
        # URLs for different services
        self.dashboard_url = "http://localhost:3002/d/a342df05-226d-4233-b5e7-f46688260197/reterminal-system-vitals?kiosk=true&refresh=5s"
        self.homeassistant_url = "http://localhost:8123/lovelace"
        self.pihole_url = "http://localhost:8080/admin"
        self.homepage_url = "http://192.168.1.76:3000"
        self.find_gpio_keys_device()
        
    def find_gpio_keys_device(self):
        """Find the gpio_keys device path (same method as Seeed examples)"""
        device_file_path = '/sys/class/input/'
        input_dev_path = '/dev/input/'
        
        try:
            os.chdir(device_file_path)
            number = len(os.listdir(os.getcwd()))
            
            for num in range(0, number):
                name_path = f"/sys/class/input/event{num}/device/name"
                if os.path.isfile(name_path):
                    try:
                        with open(name_path, 'r') as f:
                            devname = f.read().strip()
                            if devname == 'gpio_keys':
                                self.device_path = input_dev_path + f"event{num}"
                                logger.info(f"Found gpio_keys device: {self.device_path}")
                                return
                    except IOError:
                        logger.error(f"Could not read {name_path}")
                        
            if not self.device_path:
                logger.error("gpio_keys device not found!")
                sys.exit(1)
                
        except Exception as e:
            logger.error(f"Error finding device: {e}")
            sys.exit(1)
    
    def get_cli_password(self):
        """Get the current CLI password from Pi-hole"""
        try:
            result = subprocess.run(
                ["docker", "exec", "pihole", "cat", "/etc/pihole/cli_pw"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception as e:
            logger.error(f"Error getting CLI password: {e}")
        return None
    
    def open_browser_kiosk(self, url, service_name):
        """Open a URL in kiosk mode"""
        try:
            logger.info(f"Opening {service_name} in kiosk mode: {url}")
            
            browsers = [
                ["chromium-browser", "--kiosk", "--disable-infobars", "--disable-session-crashed-bubble", 
                 "--disable-restore-session-state", "--disable-translate", "--no-first-run", url],
                ["chromium", "--kiosk", "--disable-infobars", "--disable-session-crashed-bubble", 
                 "--disable-restore-session-state", "--disable-translate", "--no-first-run", url],
                ["firefox", "--kiosk", url]
            ]
            
            for browser_cmd in browsers:
                try:
                    # Kill any existing browser processes
                    subprocess.run(["pkill", "-f", browser_cmd[0]], stderr=subprocess.DEVNULL)
                    time.sleep(1)  # Wait for browser to close
                    
                    # Start new browser in kiosk mode
                    subprocess.Popen(browser_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    logger.info(f"{service_name} opened in kiosk mode with: {browser_cmd[0]}")
                    return
                except FileNotFoundError:
                    continue
                    
            logger.error("No suitable browser found")
            
        except Exception as e:
            logger.error(f"Error opening {service_name} in kiosk mode: {e}")

    def run(self):
        """Main loop to monitor button presses"""
        if not self.device_path:
            logger.error("No device path available")
            return
            
        logger.info(f"Monitoring buttons on {self.device_path}")
        logger.info("Button mappings:")
        logger.info("  F1 (leftmost): System Vitals Dashboard") 
        logger.info("  F2 (second): Home Assistant Overview")
        logger.info("  F3 (third): Pi-hole Dashboard")
        logger.info("  O (green circle): Homepage")
        logger.info("Press Ctrl+C to stop")
        
        # Open System Vitals dashboard on startup
        self.open_browser_kiosk(self.dashboard_url, "System Vitals Dashboard")
        
        try:
            device = InputDevice(self.device_path)
            
            for event in device.read_loop():
                if event.type == ecodes.EV_KEY:
                    # Parse the event (same as Seeed example)
                    keyevents = repr(event)
                    val_list = keyevents.replace('(', '').replace(')', '').replace(' ', '').split(',')
                    
                    if len(val_list) >= 5:
                        key_code = val_list[3]
                        key_value = int(val_list[4])
                        
                        # Only respond to key press events (value 1), not release (value 0)
                        if key_value == 1:
                            if key_code == '30':  # F1 button (key1 in Seeed code)
                                self.open_browser_kiosk(self.dashboard_url, "System Vitals Dashboard")
                            elif key_code == '31':  # F2 button (key2 in Seeed code)
                                self.open_browser_kiosk(self.homeassistant_url, "Home Assistant Overview")
                            elif key_code == '32':  # F3 button (key3 in Seeed code)
                                self.open_browser_kiosk(self.pihole_url, "Pi-hole Dashboard")
                            elif key_code == '33':  # O button (key4 in Seeed code) 
                                self.open_browser_kiosk(self.homepage_url, "Homepage")
                            else:
                                logger.debug(f"Unhandled key code: {key_code}")
                            
        except KeyboardInterrupt:
            logger.info("Shutting down multi-button handler...")
        except Exception as e:
            logger.error(f"Error monitoring buttons: {e}")

def signal_handler(sig, frame):
    """Handle signals gracefully"""
    print("\nShutting down multi-button handler...")
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create and run the button handler
    handler = MultiButtonHandler()
    handler.run()
