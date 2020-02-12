#!/usr/bin/env python
import os
import platform
import time
import os.path
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities


def create_driver_session(session_id, executor_url):
    from selenium.webdriver.remote.webdriver import WebDriver as RemoteWebDriver

    # Save the original function, so we can revert our patch
    org_command_execute = RemoteWebDriver.execute

    def new_command_execute(self, command, params=None):
        if command == "newSession":
            # Mock the response
            return {'success': 0, 'value': None, 'sessionId': session_id}
        else:
            return org_command_execute(self, command, params)

    # Patch the function before creating the driver object
    RemoteWebDriver.execute = new_command_execute

    new_driver = webdriver.Remote(command_executor=executor_url, desired_capabilities={})
    new_driver.session_id = session_id

    # Replace the patched function with original function
    RemoteWebDriver.execute = org_command_execute

    return new_driver

def get_browser():
  return webdriver.Firefox()

def get_chrome():
  # @todo add windows path
  data_dir = os.path.expanduser('~/Library/Application\ Support/Google/Chrome/')

  if platform.system() == "Darwin":
    os.environ["webdriver.chrome.driver"] = os.path.expanduser("~") + '/Library/Application Support/ZAP/webdriver/macos/64/chromedriver'
  else:
    os.environ["webdriver.chrome.driver"] = os.path.expanduser("~") + '/.ZAP/webdriver/linux/64/chromedriver'
  capabilities = webdriver.DesiredCapabilities.CHROME

  options = webdriver.ChromeOptions()
  options.add_argument('user-data-dir=%s' % data_dir)

  return webdriver.Chrome(executable_path=os.environ["webdriver.chrome.driver"], chrome_options=options, desired_capabilities=capabilities)



browser = get_browser()
browser.get("https://www.md5online.org/md5-decrypt.html")
time.sleep(1)
input = browser.find_element_by_css_selector('#main-form input[name="hash"]')
input.send_keys('test')
input.submit()

executor_url = browser.command_executor._url
session_id = browser.session_id

print(executor_url)
print(session_id)

driver2 = create_driver_session(session_id, executor_url)
driver2.get("https://www.md5online.org/")
