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
        self.dashboard_url = "http://localhost:3002/d/a342df05-226d-4233-b5e7-f46688260197/reterminal-system-vitals?orgId=1&refresh=5s"
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
    
    def open_pihole_auto_login(self):
        """Open Pi-hole dashboard with auto-login using CLI password"""
        try:
            logger.info("Opening Pi-hole Dashboard with auto-login")
            
            # Get the current CLI password
            cli_pw = self.get_cli_password()
            if not cli_pw:
                logger.error("Could not get CLI password, falling back to regular login")
                self.open_pihole_kiosk()
                return
            
            # Create an HTML page that will auto-login using the CLI password
            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>Pi-hole Auto Login</title>
                <style>
                    body {{ 
                        font-family: Arial, sans-serif; 
                        text-align: center; 
                        margin-top: 50px; 
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                    }}
                    .container {{
                        background: rgba(255,255,255,0.1);
                        padding: 30px;
                        border-radius: 15px;
                        backdrop-filter: blur(10px);
                        max-width: 400px;
                        margin: 0 auto;
                        box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
                    }}
                    .spinner {{
                        border: 4px solid rgba(255,255,255,0.3);
                        border-radius: 50%;
                        border-top: 4px solid #fff;
                        width: 40px;
                        height: 40px;
                        animation: spin 1s linear infinite;
                        margin: 20px auto;
                    }}
                    @keyframes spin {{
                        0% {{ transform: rotate(0deg); }}
                        100% {{ transform: rotate(360deg); }}
                    }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h2>🛡️ Pi-hole Admin</h2>
                    <div class="spinner"></div>
                    <p>Authenticating automatically...</p>
                    <p><small>Redirecting to dashboard</small></p>
                </div>
                
                <script>
                    // Auto-login function
                    function autoLogin() {{
                        fetch('http://localhost:8080/admin/api.php?login&cli_pw=' + encodeURIComponent('{cli_pw}'))
                        .then(response => response.json())
                        .then(data => {{
                            if (data && data.session_id) {{
                                // Login successful, redirect to main admin page
                                window.location.replace('http://localhost:8080/admin/index.php?session_id=' + data.session_id);
                            }} else {{
                                // Fallback to regular login page
                                window.location.replace('http://localhost:8080/admin');
                            }}
                        }})
                        .catch(error => {{
                            console.log('Auto-login failed, redirecting to login page:', error);
                            window.location.replace('http://localhost:8080/admin');
                        }});
                    }}
                    
                    // Start auto-login after a brief delay
                    setTimeout(autoLogin, 1500);
                    
                    // Fallback redirect in case API fails
                    setTimeout(function() {{
                        if (window.location.href.includes('pihole_auto.html')) {{
                            window.location.replace('http://localhost:8080/admin');
                        }}
                    }}, 8000);
                </script>
            </body>
            </html>
            """
            
            temp_html = "/tmp/pihole_auto.html"
            with open(temp_html, 'w') as f:
                f.write(html_content)
            
            browsers = [
                ["chromium-browser", "--kiosk", "--disable-infobars", "--disable-session-crashed-bubble", "--disable-restore-session-state", f"file://{temp_html}"],
                ["chromium", "--kiosk", "--disable-infobars", "--disable-session-crashed-bubble", "--disable-restore-session-state", f"file://{temp_html}"],
                ["chromium-browser", "--start-fullscreen", "--disable-infobars", f"file://{temp_html}"],
                ["chromium", "--start-fullscreen", "--disable-infobars", f"file://{temp_html}"],
                ["firefox", "--kiosk", f"file://{temp_html}"],
            ]
            
            for browser_cmd in browsers:
                try:
                    subprocess.Popen(browser_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    logger.info(f"Pi-hole auto-login opened in kiosk mode with: {browser_cmd[0]}")
                    return
                except FileNotFoundError:
                    continue
                    
            logger.error("No suitable browser found")
            
        except Exception as e:
            logger.error(f"Error opening Pi-hole with auto-login: {e}")
            # Fallback to regular kiosk mode
            self.open_pihole_kiosk()
    
    def open_pihole_kiosk(self):
        """Open Pi-hole dashboard in kiosk mode (fallback)"""
        try:
            logger.info("Opening Pi-hole Dashboard in kiosk mode")
            
            browsers = [
                ["chromium-browser", "--kiosk", "--disable-infobars", "--disable-session-crashed-bubble", "--disable-restore-session-state", self.pihole_url],
                ["chromium", "--kiosk", "--disable-infobars", "--disable-session-crashed-bubble", "--disable-restore-session-state", self.pihole_url],
                ["chromium-browser", "--start-fullscreen", "--disable-infobars", self.pihole_url],
                ["chromium", "--start-fullscreen", "--disable-infobars", self.pihole_url],
                ["firefox", "--kiosk", self.pihole_url],
            ]
            
            for browser_cmd in browsers:
                try:
                    subprocess.Popen(browser_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    logger.info(f"Pi-hole dashboard opened in kiosk mode with: {browser_cmd[0]}")
                    return
                except FileNotFoundError:
                    continue
                    
            logger.error("No suitable browser found")
            
        except Exception as e:
            logger.error(f"Error opening Pi-hole dashboard: {e}")
    
    def open_url(self, url, service_name):
        """Open a URL in the default browser"""
        try:
            logger.info(f"Opening {service_name}: {url}")
            
            browsers = [
                ["chromium-browser", "--start-maximized", "--disable-infobars", url],
                ["chromium", "--start-maximized", "--disable-infobars", url],
                ["firefox", url],
                ["x-www-browser", url],
                ["xdg-open", url]
            ]
            
            for browser_cmd in browsers:
                try:
                    subprocess.Popen(browser_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    logger.info(f"{service_name} opened with: {browser_cmd[0]}")
                    return
                except FileNotFoundError:
                    continue
                    
            logger.error("No suitable browser found")
            
        except Exception as e:
            logger.error(f"Error opening {service_name}: {e}")
    
    def run(self):
        """Main loop to monitor button presses"""
        if not self.device_path:
            logger.error("No device path available")
            return
            
        logger.info(f"Monitoring buttons on {self.device_path}")
        logger.info("Button mappings:")
        logger.info("  F1 (leftmost): System Vitals Dashboard") 
        logger.info("  F2 (second): Home Assistant Overview")
        logger.info("  F3 (third): Pi-hole Dashboard (auto-login kiosk)")
        logger.info("  O (green circle): Homepage")
        logger.info("Press Ctrl+C to stop")
        
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
                                self.open_url(self.dashboard_url, "System Vitals Dashboard")
                            elif key_code == '31':  # F2 button (key2 in Seeed code)
                                self.open_url(self.homeassistant_url, "Home Assistant Overview")
                            elif key_code == '32':  # F3 button (key3 in Seeed code)
                                self.open_pihole_auto_login()
                            elif key_code == '33':  # O button (key4 in Seeed code) 
                                self.open_url(self.homepage_url, "Homepage")
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
