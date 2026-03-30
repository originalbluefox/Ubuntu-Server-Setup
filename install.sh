#!/bin/bash

FORCE=false
RUN=false
ENV="PROD"
OPT_SELECTED=""
DOMAIN=""
PORT=""
RUNNING=""
matches=("full" "nginx" "nvm" "mysql" "docker" "certbot")

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE=true ;;
        --run)   RUN=true; ENV="PROD" ;;
        --opt)   shift; OPT_SELECTED="$1" ;;
        --domain) shift; DOMAIN="$1" ;;
        --port)   shift; PORT="$1" ;;
        *) echo "[ERR]: Unknown option $1"; exit 1 ;;
    esac
    shift
done

function intro(){
    echo "=============================="
    echo "[Build Server] Ver: 1.0.7"
    echo "=============================="
}

function is_valid_choice(){
    local input="$1"
    for item in "${matches[@]}"; do
        [[ "$input" == "$item" ]] && return 0
    done
    return 1
}

function printTask(){
    echo -e "Running: $RUNNING"
}

function clearTerminal(){
    clear
    intro
    printTask
    echo "------------------------------"
}

function interrupt(){
    local cmd_info="$1"
    echo -e "\nREADY: $cmd_info"
    read -p "Execute? (y/n): " confirm
    [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || { echo " >>> Skipped."; return 1; }
}

function run_cmd() {
    local command="$1"

    if [[ "$FORCE" == false ]]; then
        if ! interrupt "$command"; then
            return 1
        fi
    fi

    if [[ "$ENV" == "DEV" ]]; then
        printf "\n[DRY RUN]: $command\n"
    else
        printf "\n[EXECUTING]: $command\n"
        eval "$command"
        local status=$?
        
        if [ $status -ne 0 ]; then
            echo "Error detected. Attempting dpkg repair..."
            sudo dpkg --configure -a
            eval "$command"
        fi
    fi
    
    hash -r
    sleep 1 
    clearTerminal
}

function update_running(){
    RUNNING="$1"
    clearTerminal
}

# --- RENAMED FUNCTIONS TO PREVENT RECURSION ---

function do_nvm() {
    update_running "Installing NVM"
    run_cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash"
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    local nodeversion
    if [[ "$FORCE" == false ]]; then
        read -p "Enter node version [20.18.0]: " input_version
        nodeversion=${input_version:-"20.18.0"}
    else
        nodeversion="20.18.0"
    fi

    run_cmd "nvm install $nodeversion"
}

function do_nginx(){
    update_running "Installing Nginx"
    run_cmd "sudo apt install -y nginx" || return 1
    run_cmd "sudo rm -rf /etc/nginx/sites-available/default"
    
    update_running "Configuring Nginx"
    local domain_name=${DOMAIN}
    [[ -z "$domain_name" ]] && read -p "Domain: " domain_name

    local port_num=${PORT:-3000}
    [[ -z "$PORT" ]] && read -p "Port [3000]: " p_in && port_num=${p_in:-3000}

    local config="server { listen 80; server_name $domain_name; location / { proxy_pass http://localhost:$port_num; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection 'upgrade'; proxy_set_header Host \$host; proxy_cache_bypass \$http_upgrade; } }"
    
    run_cmd "echo '$config' | sudo tee /etc/nginx/sites-available/default > /dev/null"
    run_cmd "sudo systemctl restart nginx"
}

function do_certbot(){
    update_running "Installing Certbot"
    run_cmd "sudo apt install -y certbot python3-certbot-nginx"
    
    local d_name=${DOMAIN}
    [[ -z "$d_name" ]] && read -p "Domain for SSL: " d_name
    run_cmd "sudo certbot --nginx -d $d_name"
}

function do_mysql(){
    update_running "Installing MySQL"
    run_cmd "sudo apt install -y mysql-server"
}

function do_mariadb(){
    update_running "Installing MariaDB"
    run_cmd "sudo apt install -y mariadb"
}

function do_docker() {
    update_running "Docker Dependencies"
    run_cmd "sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg"

    update_running "Docker Repo Setup"
    run_cmd "sudo install -m 0755 -d /etc/apt/keyrings"
    run_cmd "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes"
    
    local repo="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable"
    run_cmd "echo '$repo' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"

    update_running "Installing Docker Engine"
    run_cmd "sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io"

    update_running "Finalizing Docker"
    run_cmd "sudo systemctl enable --now docker"
    run_cmd "docker --version" 
}

# --- UPDATED CASE TO USE NEW NAMES ---
intro
IFS=',' read -ra ADDR <<< "$OPT_SELECTED"

for choice in "${ADDR[@]}"; do
    choice=$(echo "$choice" | xargs)
    if is_valid_choice "$choice"; then
        RUNNING="$choice"
        case "$choice" in
            "full")    do_nginx && do_nvm && do_docker ;;
            "nginx")   do_nginx ;;
            "nvm")     do_nvm ;;
            "mysql")   do_mysql ;;
            "docker")  do_docker ;;
            "certbot") do_certbot ;;
            "mariadb") do_mariadb ;;
        esac
    fi
done

echo -e "\nBuild Process Complete."
