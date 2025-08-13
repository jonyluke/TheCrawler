#!/bin/bash

# Comprobar que $HOME/go/bin esté en PATH
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
  echo "[ERROR] $HOME/go/bin no está en el PATH."
  exit 1
fi

# Comprobar que $HOME/.local/bin esté en PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo "[ERROR] $HOME/.local/bin no está en el PATH."
  exit 1
fi

# Comprobar comandos
for cmd in python3 waybackurls gau hakrawler katana gospider uro httpx; do
  command -v "$cmd" >/dev/null || { echo "[ERROR] '$cmd' no está instalado o no está en el PATH."; exit 1; }
done

# Comprobar script específico
[ -f "$HOME/ParamSpider/paramspider.py" ] || { echo "[ERROR] paramspider.py no se encuentra en $HOME/ParamSpider/"; exit 1; }

# Verificación de uso correcto
DOMAIN="$1"
COOKIE="$2"

if [ -z "$DOMAIN" ]; then
    echo "Uso: $0 <dominio> [cookie]"
    exit 1
fi

# Quitar "Cookie:" si está al inicio (insensible a mayúsculas)
if [ -n "$COOKIE" ]; then
  COOKIE=$(echo "$COOKIE" | sed -E 's/^[Cc]ookie: //')
fi

# Validar que empiece por http:// o https://
if ! [[ "$DOMAIN" =~ ^https?:// ]]; then
    echo "[ERROR] El dominio debe comenzar con http:// o https://."
    exit 1
fi

# Extraer dominio sin protocolo para filtrado
DOMAIN_BASE=$(echo "$DOMAIN" | sed 's|https\?://||' | cut -d/ -f1)

# Limpiar dominio para nombre de archivo (quitar http(s):// y / )
DOMAIN_FILE=$(echo "$DOMAIN" | sed 's|https\?://||g' | tr '/' '_')

# Crear carpeta de salida
OUTPUT="./TheCrawler/$DOMAIN_FILE"
mkdir -p "$OUTPUT"

# Rutas para salidas individuales
PARAMSPIDER_FILE="$OUTPUT/paramspider.txt"
WAYBACK_FILE="$OUTPUT/waybackurls.txt"
GAU_FILE="$OUTPUT/gau.txt"
HAKRAWLER_FILE="$OUTPUT/hakrawler.txt"
KATANA_FILE="$OUTPUT/katana.txt"
GOSPIDER_FILE="$OUTPUT/gospider.txt"
RAW_URLS="$OUTPUT/raw_urls.txt"
VALIDATED_URLS="$OUTPUT/validated_urls.txt"
RESULT_FILE="$OUTPUT/results.txt"

python3 "$HOME/ParamSpider/paramspider.py" -d "$DOMAIN" --exclude "png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp,woff2,eot,ttf,otf,mp4,txt" --level high --quiet --subs False > "$PARAMSPIDER_FILE"
echo "[*] ParamSpider [$(wc -l < "$PARAMSPIDER_FILE")]"

echo "$DOMAIN" | waybackurls > "$WAYBACK_FILE"
echo "[*] Waybackurls [$(wc -l < "$WAYBACK_FILE")]"

echo "$DOMAIN" | gau --subs --blacklist "png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,js,webp,woff2,eot,ttf,otf,mp4,txt" > "$GAU_FILE" 2> /dev/null
echo "[*] Gau [$(wc -l < "$GAU_FILE")]"


if [ -n "$COOKIE" ]; then
    echo "$DOMAIN" | hakrawler -d 5 -u -h "Cookie: $COOKIE" > "$HAKRAWLER_FILE"
else
    echo "$DOMAIN" | hakrawler -d 5 -u > "$HAKRAWLER_FILE"
fi

# Filtrar solo URLs que pertenezcan al dominio base
grep "$DOMAIN_BASE" "$HAKRAWLER_FILE" > "${HAKRAWLER_FILE}.filtered"
mv "${HAKRAWLER_FILE}.filtered" "$HAKRAWLER_FILE"

echo "[*] Hakrawler [$(wc -l < "$HAKRAWLER_FILE")]"


if [ -n "$COOKIE" ]; then
    katana -u "$DOMAIN" -d 5 -jc -jsl -kf all -silent -H "Cookie: $COOKIE" -fs fqdn > "$KATANA_FILE"
else
    katana -u "$DOMAIN" -d 5 -jc -jsl -kf all -silent -fs fqdn > "$KATANA_FILE"
fi

echo "[*] Katana [$(wc -l < "$KATANA_FILE")]"


if [ -n "$COOKIE" ]; then
    gospider -s "$DOMAIN" -c 10 -d 5 -t 20 --blacklist ".(jpg|jpeg|gif|css|tif|tiff|png|ttf|woff|woff2|ico|pdf|svg|txt)" --other-source --cookie "$COOKIE" | grep -e "code-200" | awk '{print $5}' > "$GOSPIDER_FILE"
else
    gospider -s "$DOMAIN" -c 10 -d 5 -t 20 --blacklist ".(jpg|jpeg|gif|css|tif|tiff|png|ttf|woff|woff2|ico|pdf|svg|txt)" --other-source | grep -e "code-200" | awk '{print $5}' > "$GOSPIDER_FILE"
fi
echo "[*] Gospider [$(wc -l < "$GOSPIDER_FILE")]"


cat "$PARAMSPIDER_FILE" "$WAYBACK_FILE" "$GAU_FILE" "$HAKRAWLER_FILE" "$KATANA_FILE" "$GOSPIDER_FILE" > "$RAW_URLS"
echo "[+] URLs combinadas guardadas en $RAW_URLS"

echo "[*] Ordenando, deduplicando y filtrando URLs con uro..."
sort -u "$RAW_URLS" | uro > "$VALIDATED_URLS"
echo "[+] URLs validadas guardadas en $VALIDATED_URLS"

echo "[*] Filtrando URLs activas con httpx..."

if [ -n "$COOKIE" ]; then
    httpx -silent -mc 200,204,301,302,401,403,405,500,502,503,504 -l "$VALIDATED_URLS" -H "Cookie: $COOKIE" >> "$RESULT_FILE"
else
    httpx -silent -mc 200,204,301,302,401,403,405,500,502,503,504 -l "$VALIDATED_URLS" >> "$RESULT_FILE"
fi
# Filtrar solo las URLs que contengan $DOMAIN_BASE, eliminar duplicados y guardar en archivo limpio
grep "$DOMAIN_BASE" "$RESULT_FILE" | sort -u > "${RESULT_FILE}.tmp" && mv "${RESULT_FILE}.tmp" "$RESULT_FILE"

echo "[+] URLs activas guardadas en $RESULT_FILE"
