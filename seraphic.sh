#!/bin/bash

# ==========================================
# SERAPHIC INSTALLER
# ==========================================

# Prevent script from running out of interactive mode
[[ ! -t 0 ]] && { echo "Script ini harus dijalankan dalam mode interaktif!"; exit 1; }

# Version
SERAPHIC_VERSION="1.0.0"

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ==========================================
# MAIN INSTALLATION
# ==========================================

function main {
    welcome_message
    
    # Check if user is root
    check_root
    
    # Detect OS
    detect_os
    
    # Show main menu
    main_menu
}

# ==========================================
# WELCOME MESSAGE
# ==========================================
function welcome_message {
    clear
    echo -e "=================================================="
    echo -e "          \e[36mSERAPHIC PANEL INSTALLER\e[0m"
    echo -e "=================================================="
    echo ""
    echo "Version: $SERAPHIC_VERSION"
    echo ""
    echo "Welcome To Seraphic Installer"
    echo ""
    echo -e "\e[1mClick [Enter] Untuk Lanjut...\e[0m"
    read -r
}

# ==========================================
# CHECK ROOT
# ==========================================
function check_root {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\e[1;31m[ERROR]\e[0m Script ini harus dijalankan sebagai ROOT!"
        echo "Gunakan: sudo bash $0"
        exit 1
    fi
}

# ==========================================
# DETECT OS
# ==========================================
function detect_os {
    echo -e "\e[1m[1/4]\e[0m Mendeteksi Sistem Operasi..."
    
    if [ -f /etc/debian_version ]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS="$ID"
            VER="$VERSION_ID"
        fi
    elif [ -f /etc/centos-release ]; then
        OS="centos"
        VER=$(grep -oE '[0-9]+\.[0-9]+' /etc/centos-release | head -n1)
    else
        echo -e "\e[1;31m[ERROR]\e[0m OS tidak support!"
        exit 1
    fi
    
    echo -e "   \e[32m✔\e[0m OS Terdeteksi: \e[1m$OS $VER\e[0m"
    
    # Check supported versions
    case "$OS" in
        ubuntu)
            if [[ "$VER" != "20.04" && "$VER" != "22.04" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Ubuntu $VER tidak support! Gunakan 20.04 atau 22.04"
                exit 1
            fi
            ;;
        debian)
            if [[ "$VER" != "10" && "$VER" != "11" && "$VER" != "12" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m Debian $VER tidak support! Gunakan 10, 11, atau 12"
                exit 1
            fi
            ;;
        centos)
            if [[ "$VER" != "7" && "$VER" != "8" ]]; then
                echo -e "\e[1;31m[ERROR]\e[0m CentOS $VER tidak support!"
                exit 1
            fi
            ;;
    esac
    
    sleep 1
}

# ==========================================
# MAIN MENU
# ==========================================
function main_menu {
    OPTIONS=(1 "Install Panel"
             2 "Install Wings"
             3 "Install Panel + Wings (wings run after panel)"
             4 "Install Database saja"
             x "Exit")
    
    CHOICE=$(${GSUDO} --title "Seraphic Installer" --menu "Pilih Opsi Instalasi:" 22 70 15 "${OPTIONS[@]}" 2>&1)
    
    # Handle cancel
    if [ $? -ne 0 ]; then
        exit 0
    fi
    
    case "$CHOICE" in
        1) install_panel ;;
        2) install_wings ;;
        3) install_all_in_one ;;
        4) install_database ;;
        x) exit 0 ;;
    esac
}

# ==========================================
# INSTALL PANEL
# ==========================================
function install_panel {
    echo ""
    echo -e "\e[1m[2/4]\e[0m Mengumpulkan Informasi..."
    
    # Get Domain
    DOMAIN=""
    while [ -z "$DOMAIN" ]; do
        DOMAIN=$(${GSUDO} --inputbox "Masukkan Domain/Subdomain untuk Panel:" 8 50 "panel.seraphic.net" 3>&1 1>&2 2>&3)
    done
    
    # Get Email for SSL
    EMAIL=""
    while [ -z "$EMAIL" ]; do
        EMAIL=$(${GSUDO} --inputbox "Masukkan Email untuk SSL Certificate:" 8 50 "admin@$DOMAIN" 3>&1 1>&2 2>&3)
    done
    
    # Get Database Password
    DBPASS=""
    while [ -z "$DBPASS" ]; do
        DBPASS=$(${GSUDO} --passwordbox "Masukkan Password MySQL:" 8 50 3>&1 1>&2 2>&3)
    done
    
    # Confirm
    ${GSUDO} --title "Konfirmasi Instalasi" --yesno "Akan menginstall Seraphic Panel di $DOMAIN\n\nLanjutkan?" 10 50
    
    if [ $? -ne 0 ]; then
        main_menu
        return
    fi
    
    echo -e "\e[1m[3/4]\e[0m Memulai Instalasi..."
    
    # Update System
    update_system
    
    # Install Dependencies
    install_dependencies
    
    # Install Webserver & PHP
    install_webserver_php
    
    # Install Database
    install_and_configure_mariadb
    
    # Download & Configure Seraphic Panel
    download_panel
    
    # Configure Nginx
    configure_nginx
    
    # SSL
    ask_ssl
    
    # Finish
    success_message
}

# ==========================================
# UPDATE SYSTEM
# ==========================================
function update_system {
    echo -e "   \e[1m►\e[0m Update sistem..."
    if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        apt update -y && apt upgrade -y
    elif [ "$OS" == "centos" ]; then
        yum update -y
    fi
}

# ==========================================
# INSTALL DEPENDENCIES
# ==========================================
function install_dependencies {
    echo -e "   \e[1m►\e[0m Menginstall dependensi..."
    
    # Install curl, git, unzip, etc
    if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        apt install -y curl wget git unzip zip tar software-properties-common
    elif [ "$OS" == "centos" ]; then
        yum install -y curl wget git unzip zip tar
    fi
}

# ==========================================
# INSTALL WEBSERVER & PHP
# ==========================================
function install_webserver_php {
    echo -e "   \e[1m►\e[0m Menginstall Nginx & PHP..."
    
    if [ "$OS" == "ubuntu" ]; then
        # Add PHP Repository
        add-apt-repository -y ppa:ondrej/php
        apt update
        
        # Install PHP 8.1 + Extensions
        apt install -y php8.1 php8.1-fpm php8.1-cli php8.1-mysql php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-intl php8.1-bcmath php8.1-gnupg php8.1-sqlite3
        
    elif [ "$OS" == "debian" ]; then
        # Install PHP from sury repo
        apt install -y apt-transport-https lsb-release ca-certificates curl
        curl -sSL https://packages.sury.org/php/apt.gpg | apt-key add -
        echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
        apt update
        apt install -y php8.1 php8.1-fpm php8.1-cli php8.1-mysql php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-intl php8.1-bcmath php8.1-sqlite3
    fi
    
    # Install Nginx
    apt install -y nginx
}

# ==========================================
# INSTALL MARIADB
# ==========================================
function install_and_configure_mariadb {
    echo -e "   \e[1m►\e[0m Menginstall MariaDB..."
    
    if [ "$OS" == "debian" ] || [ "$OS" == "ubuntu" ]; then
        apt install -y mariadb-server mariadb-client
    elif [ "$OS" == "centos" ]; then
        yum install -y mariadb-server mariadb
    fi
    
    # Start & Enable
    systemctl start mariadb
    systemctl enable mariadb
    
    # Secure Installation (Automated)
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DBPASS';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Create Database
    mysql -u root -p"$DBPASS" -e "CREATE DATABASE seraphic_panel;"
    mysql -u root -p"$DBPASS" -e "CREATE USER 'seraphic'@'localhost' IDENTIFIED BY '$DBPASS';"
    mysql -u root -p"$DBPASS" -e "GRANT ALL PRIVILEGES ON seraphic_panel.* TO 'seraphic'@'localhost';"
    mysql -u root -p"$DBPASS" -e "FLUSH PRIVILEGES;"
}

# ==========================================
# DOWNLOAD PANEL
# ==========================================
function download_panel {
    echo -e "   \e[1m►\e[0m Mendownload Seraphic Panel..."
    
    mkdir -p /var/www/seraphic
    cd /var/www/seraphic
    
    # Download latest release (contoh: pterodactyl panel source)
    # Anda ganti dengan source code aplikasi Anda
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    
    tar -xzf panel.tar.gz
    rm panel.tar.gz
    
    # Set permissions
    chown -R www-data:www-data /var/www/seraphic
    chmod -R 755 /var/www/seraphic/storage /var/www/seraphic/bootstrap/cache
}

# ==========================================
# CONFIGURE NGINX
# ==========================================
function configure_nginx {
    echo -e "   \e[1m►\e[0m Mengkonfigurasi Nginx..."
    
    cat > /etc/nginx/sites-available/seraphic << 'EOF'
server {
    listen 80;
    server_name __DOMAIN__;

    root /var/www/seraphic/public;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    sed -i "s/__DOMAIN__/$DOMAIN/g" /etc/nginx/sites-available/seraphic
    ln -sf /etc/nginx/sites-available/seraphic /etc/nginx/sites-enabled/seraphic
    
    # Test & Reload
    nginx -t
    systemctl reload nginx
}

# ==========================================
# ASK SSL
# ==========================================
function ask_ssl {
    ${GSUDO} --title "SSL Certificate" --yesno "Ingin install SSL otomatis via Let's Encrypt?" 8 50
    
    if [ $? -eq 0 ]; then
        echo -e "   \e[1m►\e[0m Menginstall Certbot..."
        apt install -y certbot python3-certbot-nginx
        
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
        
        systemctl reload nginx
    fi
}

# ==========================================
# INSTALL WINGS (DAEMON)
# ==========================================
function install_wings {
    ${GSUDO} --title "Seraphic Wings" --msgbox "Installer Wings (Daemon) untuk menjalankan game server.\n\nPastikan Anda sudah menginstall Panel terlebih dahulu!" 10 50
    
    # Install Docker
    echo -e "   \e[1m►\e[0m Menginstall Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    systemctl enable docker
    systemctl start docker
    
    # Install Wings
    echo -e "   \e[1m►\e[0m Menginstall Wings..."
    mkdir -p /etc/seraphic/wings
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    
    # Create Service
    cat > /etc/systemd/system/seraphic-wings.service << 'EOF'
[Unit]
Description=Seraphic Wings Daemon
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/etc/seraphic/wings
ExecStart=/usr/local/bin/wings
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable seraphic-wings
    
    success_message
}

# ==========================================
# INSTALL ALL IN ONE
# ==========================================
function install_all_in_one {
    install_panel
    install_wings
}

# ==========================================
# INSTALL DATABASE ONLY
# ==========================================
function install_database {
    DBPASS=""
    while [ -z "$DBPASS" ]; do
        DBPASS=$(${GSUDO} --passwordbox "Masukkan Password MySQL yang diinginkan:" 8 50 3>&1 1>&2 2>&3)
    done
    
    install_and_configure_mariadb
    
    success_message
}

# ==========================================
# SUCCESS MESSAGE
# ==========================================
function success_message {
    echo ""
    echo -e "\e[1;32m════════════════════════════════════════════════════════════\e[0m"
    echo -e "                    \e[1;32mINSTALASI SELESAI!\e[0m"
    echo -e "\e[1;32m════════════════════════════════════════════════════════════\e[0m"
    echo ""
    echo "Terima kasih telah menggunakan Seraphic Installer."
    echo ""
    
    ${GSUDO} --title "Selesai" --msgbox "Instalasi selesai! Silakan akses domain Anda." 8 50
    
    exit 0
}

# ==========================================
# RUN MAIN
# ==========================================
main
