#!/bin/bash

echo "🔍 Vérification des correspondances server_name <-> certificat SSL"
echo

NGINX_DIR="/etc/nginx/sites-enabled"
TMPCERT="/tmp/cert.$$"

for conf in "$NGINX_DIR"/*.conf; do
    echo "📄 Fichier : $conf"

    # Récupère les server_name (ligne unique, plusieurs noms possibles)
    while read -r line; do
        names=$(echo "$line" | sed -E 's/^\s*server_name\s+//;s/;//')
        for name in $names; do
            echo "  🔹 Test de $name"

            # Connexion SSL
            timeout 5 openssl s_client -connect "$name:443" -servername "$name" < /dev/null 2>/dev/null |
                openssl x509 -noout -text > "$TMPCERT"

            if [[ $? -ne 0 ]]; then
                echo "     ❌ Impossible de récupérer le certificat SSL"
                continue
            fi

            # Récupère CN
            cn=$(grep "Subject:" "$TMPCERT" | sed -E 's/.*CN=([^,\/]+).*/\1/')
            # Récupère SANs
            sans=$(grep -A1 "Subject Alternative Name" "$TMPCERT" | tail -n1 | sed -E 's/DNS://g;s/, /\n/g')

            # Vérifie si le nom est dans la liste
            match_found=false
            for san in $sans; do
                [[ "$san" == "$name" ]] && match_found=true
            done

            if $match_found || [[ "$cn" == "$name" ]]; then
                echo "     ✅ Match trouvé dans le certificat (CN/SAN)"
            else
                echo "     ⚠️  Pas de correspondance CN/SAN — CN: $cn"
            fi
        done
    done < <(grep -E '^\s*server_name' "$conf")

    echo
done

rm -f "$TMPCERT"
