#!/bin/bash

# Define the database path
DB_PATH="/etc/x-ui/x-ui.db"

# Function to check if curl is installed
check_curl() {
    if ! command -v curl &> /dev/null
    then
        echo "curl could not be found, installing..."
        install_curl
    else
        echo "curl is already installed."
    fi
}

# Function to install curl
install_curl() {
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y curl
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y curl
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y curl
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm curl
    else
        echo "Package manager not found. Please install curl manually."
        exit 1
    fi
}

# Function to check if sqlite3 is installed
check_sqlite3() {
    if ! command -v sqlite3 &> /dev/null
    then
        echo "sqlite3 could not be found, installing..."
        install_sqlite3
    else
        echo "sqlite3 is already installed."
    fi
}

# Function to install sqlite3
install_sqlite3() {
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y sqlite3
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y sqlite
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y sqlite
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm sqlite
    else
        echo "Package manager not found. Please install sqlite3 manually."
        exit 1
    fi
}

# Function to check if certbot is installed
check_certbot() {
    if ! command -v certbot &> /dev/null
    then
        echo "certbot could not be found, installing..."
        install_certbot
    else
        echo "certbot is already installed."
    fi
}

# Function to install certbot
install_certbot() {
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y certbot
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y certbot
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y certbot
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm certbot
    else
        echo "Package manager not found. Please install certbot manually."
        exit 1
    fi
}

# Function to check if SSL settings are already present
check_if_ssl_present() {
    local ssl_detected=$(grep -a 'webCertFile' "$DB_PATH" 2>/dev/null | tr -d '\0')
    if [ -n "$ssl_detected" ]; then
        echo "SSL cert detected in settings, continuing to update SSL settings."
    fi
}

# Function to remove existing SSL entries in the database
remove_existing_ssl_entries() {
    echo "Removing existing SSL entries from the database..."
    sqlite3 "$DB_PATH" "DELETE FROM settings WHERE key = 'webCertFile' OR key = 'webKeyFile';"
    echo "Existing SSL entries removed."
}

# Function to get the last ID in the settings table
get_last_id() {
    LAST_ID=$(sqlite3 "$DB_PATH" "SELECT IFNULL(MAX(id), 0) FROM settings;")
    echo "The last ID in the settings table is $LAST_ID"
}

# Function to execute SQL inserts
execute_sql_inserts() {
    local next_id=$((LAST_ID + 1))
    local second_id=$((next_id + 1))
    local cert_path="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    local key_path="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    local SQL_INSERT_TEMPLATE="
INSERT INTO settings VALUES ($next_id, 'webCertFile', '$cert_path');
INSERT INTO settings VALUES ($second_id, 'webKeyFile', '$key_path');
"
    sqlite3 "$DB_PATH" "$SQL_INSERT_TEMPLATE"
    echo "SQL inserts executed with cert path: $cert_path and key path: $key_path."
}

# Function to generate SSL certificate using certbot
gen_ssl_cert() {
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
    if [ $? -eq 0 ]; then
        echo "SSL certificates generated for domain $DOMAIN."
    else
        echo "Failed to generate SSL certificates for domain $DOMAIN. Please check the logs for details."
        exit 1
    fi
}

# Function to prompt user for the FreemyIP link and extract the token and domain
prompt_for_link() {
    read -p "Please enter your FreemyIP update link: " FREEMYIP_LINK
    TOKEN=$(echo "$FREEMYIP_LINK" | grep -oP '(?<=token=)[^&]*')
    DOMAIN=$(echo "$FREEMYIP_LINK" | grep -oP '(?<=domain=)[^&]*')
    if [ -z "$TOKEN" ] || [ -z "$DOMAIN" ]; then
        echo "Invalid link. Please provide a valid FreemyIP link."
        exit 1
    fi
    echo "Extracted token: $TOKEN"
    echo "Extracted domain: $DOMAIN"
}

# Function to prompt user for domain and email
prompt_for_domain_and_email() {
    read -p "Please enter a valid email address for SSL registration: " EMAIL
}

# Function to update dynamic DNS
update_dynamic_dns() {
    echo "Updating DNS record for $DOMAIN..."
    curl "https://freemyip.com/update?token=$TOKEN&domain=$DOMAIN"
    echo "DNS update completed."
}

# Function to setup automated certificate renewal
setup_certbot_renewal() {
    # Add renewal command to cron job
    (crontab -l ; echo "0 3 * * * certbot renew --quiet") | crontab -
    echo "Certbot renewal scheduled in cron."
}

# Main script execution
check_curl
check_sqlite3
check_if_ssl_present
check_certbot
prompt_for_domain_and_email
prompt_for_link
update_dynamic_dns
remove_existing_ssl_entries  
gen_ssl_cert
get_last_id
execute_sql_inserts
setup_certbot_renewal
