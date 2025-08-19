# TheCrawler

## Installation 

```
sudo apt install nuclei golang ripgrep && git clone https://github.com/0xKayala/ParamSpider "$HOME/ParamSpider" && go install github.com/003random/getJS/v2@latest && go install  github.com/lc/subjs@latest && go install github.com/lc/gau/v2/cmd/gau@latest && go install github.com/tomnomnom/waybackurls@latest && go install github.com/hakluke/hakrawler@latest && go install github.com/projectdiscovery/katana/cmd/katana@latest && go install github.com/jaeles-project/gospider@latest && pipx install uro && [ "$tool" = "uro" ] && [ -f "$HOME/.local/bin/uro" ] && export PATH="$HOME/.local/bin:$PATH"; [[ ":$PATH:" != *":$HOME/go/bin:"* ]] && export PATH="$HOME/go/bin:$PATH" && wget -q https://github.com/projectdiscovery/httpx/releases/download/v1.7.1/httpx_1.7.1_linux_amd64.zip && unzip -q httpx_1.7.1_linux_amd64.zip && chmod +x httpx && sudo mv httpx /usr/bin/httpx && rm httpx_1.7.1_linux_amd64.zip
```
## How To Use

```
./TheCrawler.sh <domain> [cookie]
```

## Examples of use

### XSS
```
grep '=' TheCrawler/domain.com/results.txt | dalfox pipe --fast-scan --skip-mining-all -S -C "user_session=qUQV0tPNlvAn" 
```

```
xsstrike --seeds <(grep '=' TheCrawler/domain.com/results.txt)
```

### Nuclei
```
cat TheCrawler/domain.com/results.txt | nuclei -t /home/kali/.local/nuclei-templates -dast -H "Cookie: sessionid=abc123;"
```
### Open Redirection
```
cat TheCrawler/domain.com/results.txt | gf redirect | openredirex
```

### BurpSuite
```
Import with SiteMap+
```

