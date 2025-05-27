#!/usr/bin/env python3
"""
Cloudflare Dynamic DNS Updater

This script automatically updates a Cloudflare DNS record to point to your current public IP address.
It only updates the record if your IP has changed, reducing unnecessary API calls.

Requirements:
- Python 3.6+
- requests library (install with: pip install requests)

Setup:
1. Get your Cloudflare API token from the Cloudflare dashboard
   (Go to My Profile > API Tokens > Create Token > Edit zone DNS template)
2. Find your Zone ID in the Cloudflare dashboard
   (Domain overview page > Right sidebar)
3. Update the configuration section below

Usage:
- Run manually: python cloudflare_ddns.py
- Set up as a cron job to run automatically (e.g., every hour)
"""

import logging
import os
import sys

import requests
from dotenv import load_dotenv

# Load dotenv environment for local environment vars.
# These should be set in a .env file.
load_dotenv()

# ========== CONFIGURATION ==========
# Replace these with your actual values
CLOUDFLARE_API_TOKEN = os.environ.get("CLOUDFLARE_API_TOKEN")
ZONE_ID = os.environ.get("ZONE_ID")
RECORD_NAME = os.environ.get("RECORD_NAME")  # The DNS record to update (e.g., home.example.com)
RECORD_TYPE = "A"  # Usually 'A' for IPv4 addresses
TTL = 120  # Time to live in seconds (1 = automatic)
PROXIED = True  # Whether the record is proxied through Cloudflare (orange cloud)

# IP detection service options - you can use any one of these
IP_DETECTION_SERVICES = [
    "https://api.ipify.org",
    "https://ifconfig.me/ip",
    "https://icanhazip.com",
    "https://checkip.amazonaws.com"
]

# Retrieve optional desired logger name from environment.
LOGGER_NAME = os.environ.get("LOGGER_NAME")

# ===================================

# Set up basic logger to only output to stdout.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

if LOGGER_NAME:
    # Get or create the specified logger.
    logger = logging.getLogger(LOGGER_NAME)
    # Add a file handler to persist logs in a file.
    log_handler = logging.FileHandler(f"{LOGGER_NAME}.log")
    log_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logger.addHandler(log_handler)
else:
    # Get or create default logger.
    logger = logging.getLogger('cloudflare_ddns')


def get_current_ip():
    """Get the current public IP address using multiple services for reliability"""
    for service_url in IP_DETECTION_SERVICES:
        try:
            response = requests.get(service_url, timeout=10)
            if response.status_code == 200:
                ip = response.text.strip()
                logger.info(f"Current public IP address: {ip}")
                return ip
        except Exception as e:
            logger.warning(f"Failed to get IP from {service_url}: {e}")

    logger.error("Failed to get current public IP address from any service")
    return None


def get_dns_record():
    """Get the current DNS record from Cloudflare"""
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records"
    params = {"type": RECORD_TYPE, "name": RECORD_NAME}
    headers = {
        'X-Auth-Email': 'xaviercgill@gmail.com',
        'X-Auth-Key': 'dff4b1c765a6c0b5619e9657374d9e45553ff',
    }

    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        data = response.json()

        if data["success"] and len(data["result"]) > 0:
            record = data["result"][0]
            logger.info(f"Found existing DNS record: {record['name']} ({record['content']})")
            return record
        else:
            logger.warning(f"No existing DNS record found for {RECORD_NAME}")
            return None
    except Exception as e:
        logger.error(f"Error getting DNS record: {e}")
        return None


def update_dns_record(record_id, ip_address):
    """Update the DNS record with a new IP address"""
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records/{record_id}"
    headers = {
        'X-Auth-Email': 'xaviercgill@gmail.com',
        'X-Auth-Key': 'dff4b1c765a6c0b5619e9657374d9e45553ff',
    }
    payload = {
        "type": RECORD_TYPE,
        "name": RECORD_NAME,
        "content": ip_address,
        "ttl": TTL,
        "proxied": PROXIED
    }

    try:
        response = requests.put(url, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()

        if data["success"]:
            logger.info(f"Successfully updated DNS record to {ip_address}")
            return True
        else:
            logger.error(f"Failed to update DNS record: {data['errors']}")
            return False
    except Exception as e:
        logger.error(f"Error updating DNS record: {e}")
        return False


def create_dns_record(ip_address):
    """Create a new DNS record"""
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records"
    headers = {
        'X-Auth-Email': 'xaviercgill@gmail.com',
        'X-Auth-Key': 'dff4b1c765a6c0b5619e9657374d9e45553ff',
    }
    payload = {
        "type": RECORD_TYPE,
        "name": RECORD_NAME,
        "content": ip_address,
        "ttl": TTL,
        "proxied": PROXIED
    }

    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()

        if data["success"]:
            logger.info(f"Successfully created DNS record for {RECORD_NAME} with IP {ip_address}")
            return True
        else:
            logger.error(f"Failed to create DNS record: {data['errors']}")
            return False
    except Exception as e:
        logger.error(f"Error creating DNS record: {e}")
        return False


def validate_config():
    """Validate the configuration values"""
    if CLOUDFLARE_API_TOKEN == "your_cloudflare_api_token_here":
        logger.error("Please update the script with your Cloudflare API token")
        return False
    if ZONE_ID == "your_zone_id_here":
        logger.error("Please update the script with your Zone ID")
        return False
    if RECORD_NAME == "your.domain.com":
        logger.error("Please update the script with your domain name")
        return False
    return True


def main():
    logger.info("Starting Cloudflare Dynamic DNS update check")

    if not validate_config():
        return

    # Get current public IP address
    current_ip = get_current_ip()
    if not current_ip:
        return

    # Get existing DNS record
    record = get_dns_record()

    if record:
        # If IP hasn't changed, no need to update
        if record["content"] == current_ip:
            logger.info("IP address hasn't changed, no update needed")
            return

        # Update the existing record
        update_dns_record(record["id"], current_ip)
    else:
        # Create a new record if none exists
        create_dns_record(current_ip)

    logger.info("Dynamic DNS update process completed")


if __name__ == "__main__":
    main()