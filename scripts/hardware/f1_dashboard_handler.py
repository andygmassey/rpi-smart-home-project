#!/usr/bin/env python3

"""
reTerminal F1 Button Handler
Opens Grafana System Vitals Dashboard when F1 is pressed
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

class F1ButtonHandler:
    def __init__(self):
        self.device_path = None
        # Direct URL to your specific dashboard
        self.dashboard_url = "http://localhost:3002/d/a342df05-226d-4233-b5e7-f46688260197/reterminal-system-vitals?orgId=1&refresh=5s"
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
    
    def auto_login_and_open_dashboard(self):
        """Auto-login to Grafana and open the dashboard"""
        try:
            logger.info("F1 pressed - Opening System Vitals Dashboard with auto-login")
            
            # Create a script that handles login and navigation
            login_script = f"""
            # Wait for page load, then try to login and navigate
            sleep 2
            
            # Try to login with your credentials (adjust as needed)
            # This uses xdotool to simulate keyboard input
            xdotool search --name "Grafana" windowfocus
            sleep 1
            
            # Type username (adjust 'andymassey' if different)
            xdotool type "andymassey"
            xdotool key Tab
            
            # You'll need to set a password or use the default
            # For now, just navigate to the URL directly after login
            sleep 1
            xdotool key ctrl+l  # Focus address bar
            xdotool type "{self.dashboard_url}"
            xdotool key Return
            """
            
            # First open browser to Grafana
            browsers = [
                ["chromium-browser", "--start-maximized", "--disable-infobars", "http://localhost:3002"],
                ["chromium", "--start-maximized", "--disable-infobars", "http://localhost:3002"],
                ["firefox", "http://localhost:3002"]
            ]
            
            browser_opened = False
            for browser_cmd in browsers:
                try:
                    subprocess.Popen(browser_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    logger.info(f"Browser opened with: {browser_cmd[0]}")
                    browser_opened = True
                    break
                except FileNotFoundError:
                    continue
            
            if browser_opened:
                # Wait a moment, then navigate directly to dashboard
                time.sleep(3)
                try:
                    # Try to navigate directly to the dashboard URL
                    subprocess.run([
                        "xdotool", "search", "--name", "Grafana", "windowfocus",
                        "key", "ctrl+l", "type", self.dashboard_url, "key", "Return"
                    ], capture_output=True, timeout=10)
                except:
                    # If xdotool fails, just log it
                    logger.info("Direct navigation attempted, may need manual login")
            else:
                logger.error("No suitable browser found")
                
        except Exception as e:
            logger.error(f"Error opening dashboard: {e}")
    
    def open_dashboard_simple(self):
        """Simple approach - open browser directly to dashboard URL"""
        try:
            logger.info("F1 pressed - Opening System Vitals Dashboard")
            
            browsers = [
                ["chromium-browser", "--start-maximized", "--disable-infobars", self.dashboard_url],
                ["chromium", "--start-maximized", "--disable-infobars", self.dashboard_url],
                ["firefox", self.dashboard_url]
            ]
            
            for browser_cmd in browsers:
                try:
                    subprocess.Popen(browser_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    logger.info(f"Dashboard URL opened with: {browser_cmd[0]}")
                    return
                except FileNotFoundError:
                    continue
                    
            logger.error("No suitable browser found")
            
        except Exception as e:
            logger.error(f"Error opening dashboard: {e}")
    
    def run(self):
        """Main loop to monitor button presses"""
        if not self.device_path:
            logger.error("No device path available")
            return
            
        logger.info(f"Monitoring F1 button on {self.device_path}")
        logger.info("Press F1 to open System Vitals Dashboard")
        logger.info("Press Ctrl+C to stop")
        
        try:
            device = InputDevice(self.device_path)
            
            for event in device.read_loop():
                if event.type == ecodes.EV_KEY:
                    # Parse the event (same as Seeed example)
                    keyevents = repr(event)
                    val_list = keyevents.replace('(', '').replace(')', '').replace(' ', '').split(',')
                    
                    # F1 button corresponds to key code 30 and press event (value 1)
                    if len(val_list) >= 5:
                        key_code = val_list[3]
                        key_value = int(val_list[4])
                        
                        if key_code == '30' and key_value == 1:  # F1 pressed (not released)
                            self.open_dashboard_simple()
                            
        except KeyboardInterrupt:
            logger.info("Shutting down F1 button handler...")
        except Exception as e:
            logger.error(f"Error monitoring buttons: {e}")

def signal_handler(sig, frame):
    """Handle signals gracefully"""
    print("\nShutting down F1 button handler...")
    sys.exit(0)

if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Create and run the button handler
    handler = F1ButtonHandler()
    handler.run()
