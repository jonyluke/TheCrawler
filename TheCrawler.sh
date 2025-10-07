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
for cmd in python3 waybackurls gau hakrawler katana gospider uro httpx subjs getJS rg; do
  command -v "$cmd" >/dev/null || { echo "[ERROR] '$cmd' no está instalado o no está en el PATH."; exit 1; }
done

# Comprobar script específico
[ -f "$HOME/ParamSpider/paramspider.py" ] || { echo "[ERROR] paramspider.py no se encuentra en $HOME/ParamSpider/"; exit 1; }

# Verificación de uso correcto
DOMAIN="$1"
COOKIE="${2:-}"

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
OUTPUT="./output/$DOMAIN_FILE"
mkdir -p "$OUTPUT"

# Rutas para salidas individuales
PARAMSPIDER_FILE="$OUTPUT/paramspider.txt"
WAYBACK_FILE="$OUTPUT/waybackurls.txt"
GAU_FILE="$OUTPUT/gau.txt"
HAKRAWLER_FILE="$OUTPUT/hakrawler.txt"
KATANA_FILE="$OUTPUT/katana.txt"
GOSPIDER_FILE="$OUTPUT/gospider.txt"
SUBJS_FILE="$OUTPUT/subjs.txt"
GETJS_FILE="$OUTPUT/getjs.txt"
JS_PATHS="$OUTPUT/JS_paths.txt"
RAW_URLS="$OUTPUT/raw_urls.txt"
VALIDATED_URLS="$OUTPUT/validated_urls.txt"
RESULT_FILE="$OUTPUT/results.txt"
SECRETS_FILE="$OUTPUT/secrets.txt"

# ParamSpider
source "$HOME/ParamSpider/.venv/bin/activate"
python3 "$HOME/ParamSpider/paramspider.py" -d "$DOMAIN" --exclude "png,jpg,gif,jpeg,swf,woff,svg,pdf,json,css,webp,woff2,eot,ttf,otf,mp4" --level high --quiet --subs False -o "$PARAMSPIDER_FILE"
deactivate
echo "[*] ParamSpider [$(wc -l < "$PARAMSPIDER_FILE")]"

# Waybackurls
echo "$DOMAIN" | waybackurls > "$WAYBACK_FILE"
echo "[*] Waybackurls [$(wc -l < "$WAYBACK_FILE")]"

# gau
echo "$DOMAIN" | gau --subs --blacklist "png,jpg,gif,jpeg,swf,woff,svg,json,css,webp,woff2,eot,ttf,otf,mp4" > "$GAU_FILE" 2>/dev/null
echo "[*] Gau [$(wc -l < "$GAU_FILE")]"

# hakrawler
if [ -n "$COOKIE" ]; then
    echo "$DOMAIN" | hakrawler -d 5 -u -h "Cookie: $COOKIE" > "$HAKRAWLER_FILE"
else
    echo "$DOMAIN" | hakrawler -d 5 -u > "$HAKRAWLER_FILE"
fi
grep -F "$DOMAIN_BASE" "$HAKRAWLER_FILE" > "${HAKRAWLER_FILE}.filtered" || true
mv "${HAKRAWLER_FILE}.filtered" "$HAKRAWLER_FILE"
echo "[*] Hakrawler [$(wc -l < "$HAKRAWLER_FILE")]"

# katana
if [ -n "$COOKIE" ]; then
    katana -u "$DOMAIN" -d 5 -jc -jsl -kf all -silent -H "Cookie: $COOKIE" -fs fqdn > "$KATANA_FILE"
else
    katana -u "$DOMAIN" -d 5 -jc -jsl -kf all -silent -fs fqdn > "$KATANA_FILE"
fi
echo "[*] Katana [$(wc -l < "$KATANA_FILE")]"

# gospider
if [ -n "$COOKIE" ]; then
    gospider -s "$DOMAIN" -c 10 -d 5 -t 20 --blacklist ".(jpg|jpeg|gif|css|tif|tiff|png|ttf|woff|woff2|ico|svg)" --other-source --cookie "$COOKIE" \
      | grep -e "code-200" | awk '{print $5}' > "$GOSPIDER_FILE"
else
    gospider -s "$DOMAIN" -c 10 -d 5 -t 20 --blacklist ".(jpg|jpeg|gif|css|tif|tiff|png|ttf|woff|woff2|ico|svg)" --other-source \
      | grep -e "code-200" | awk '{print $5}' > "$GOSPIDER_FILE"
fi
echo "[*] Gospider [$(wc -l < "$GOSPIDER_FILE")]"

# Combinar primeras fuentes
cat "$PARAMSPIDER_FILE" "$WAYBACK_FILE" "$GAU_FILE" "$HAKRAWLER_FILE" "$KATANA_FILE" "$GOSPIDER_FILE" > "$RAW_URLS"


# Dedup + normalización con uro
cat "$RAW_URLS" | sort -u | uro > "$VALIDATED_URLS"
grep -F "$DOMAIN_BASE" "$VALIDATED_URLS" | sort -u -o "$VALIDATED_URLS"

# subjs  
cat "$VALIDATED_URLS" | subjs > "$SUBJS_FILE"
echo "[*] subJS [$(wc -l < "$SUBJS_FILE")]"


# getJS
if [ -n "$COOKIE" ]; then
  cat "$VALIDATED_URLS" | getJS -complete -header "Cookie: $COOKIE" > "$GETJS_FILE"
else
  cat "$VALIDATED_URLS" | getJS -complete > "$GETJS_FILE"
fi
echo "[*] getJS [$(wc -l < "$GETJS_FILE")]"

# Añadir rutas JS detectadas al VALIDATED_URLS y normalizar
cat "$GETJS_FILE" "$SUBJS_FILE" >> "$VALIDATED_URLS"

tmp_valid=$(mktemp)
grep -F "$DOMAIN_BASE" "$VALIDATED_URLS"  | sort -u | uro > "$tmp_valid" && mv "$tmp_valid" "$VALIDATED_URLS"

echo "[+] URLs validadas guardadas en $VALIDATED_URLS"


# httpx (filtrado activos)
if [ -n "$COOKIE" ]; then
    httpx -silent -mc 200,204,301,302,401,403,405,500,502,503,504 -l "$VALIDATED_URLS" -H "Cookie: $COOKIE" >> "$RESULT_FILE"
else
    httpx -silent -mc 200,204,301,302,401,403,405,500,502,503,504 -l "$VALIDATED_URLS" >> "$RESULT_FILE"
fi
echo "[+] URLs activas guardadas en $RESULT_FILE"

sort -u "$RESULT_FILE" -o "$RESULT_FILE"

# Extraer solo rutas .js interesantes a JS_PATHS
awk -v IGNORECASE=1 '{
  u=$0; sub(/[?#].*$/,"",u)
  h=""; p=u
  if (match(u,/^https?:\/\/[^\/]+/)) { h=substr(u,RSTART,RLENGTH); p=substr(u,RSTART+RLENGTH) }
  gsub(/\/+/, "/", p)                
  u=h p
  f=p; sub(/^.*\//,"",f)              # filename
  if (f~/\.js$/ && f!~/(jquery|bootstrap|react(-dom)?|vue|angular|moment|lodash|underscore|modernizr|dataTables?|jsrender|json2|prototype|deployjava|hacktimer|recaptcha|ion[.-]?rangeslider|izi?modal)/ && !s[u]++) print u
}' "$RESULT_FILE" > "$JS_PATHS"


# Descargar JS (nombre = ruta_sin_dominio + MD5 del contenido)
mkdir -p "$OUTPUT/js_files"

# Contar total de JS a descargar
TOTAL=$(grep -c . "$JS_PATHS")
COUNT=0

while read -r url; do
    [ -z "$url" ] && continue
    COUNT=$((COUNT+1))

    # Mostrar progreso en la misma línea
    printf "\r[*] Descargando JS [%d/%d]" "$COUNT" "$TOTAL"

    base=$(basename "$(echo "$url" | sed -E 's/[?#].*$//')")

    tmpfile=$(mktemp)
    if [ -n "$COOKIE" ]; then
        curl -skLf --compressed -H "Cookie: $COOKIE" "$url" -o "$tmpfile"
    else
        curl -skLf --compressed "$url" -o "$tmpfile"
    fi

    if [ -s "$tmpfile" ]; then
        hash=$(md5sum "$tmpfile" | awk '{print $1}')
        outfile="$OUTPUT/js_files/${hash}_${base}"
        mv "$tmpfile" "$outfile"
    else
        rm -f "$tmpfile"
    fi
done < "$JS_PATHS"

# Salto de línea después del progreso
echo

echo "[+] Archivos JS descargados en $OUTPUT/js_files"

# Buscar secretos en archivos JS usando patrones externos
if command -v rg >/dev/null 2>&1; then
  rg -nH --no-heading --color never -a -S -P \
    -g '!**/*.map' -g '!**/*.js.map' -g '*.js' \
    -f patterns.txt \
    "$OUTPUT/js_files" > "$SECRETS_FILE"
fi

[ -s "$SECRETS_FILE" ] && sort -u "$SECRETS_FILE" -o "$SECRETS_FILE"

echo "[*] Secrets [$(wc -l < "$SECRETS_FILE")]"
