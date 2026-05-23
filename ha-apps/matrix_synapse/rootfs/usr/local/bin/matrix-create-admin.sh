#!/usr/bin/with-contenv bashio
# ============================================================================
# Matrix Addon — Ersten Admin-User anlegen
# Aufruf: /usr/local/bin/matrix-create-admin.sh <username> <password>
# ============================================================================

SYNAPSE_CONFIG="/data/matrix/synapse/homeserver.yaml"

USERNAME="${1}"
PASSWORD="${2}"

if [ -z "${USERNAME}" ] || [ -z "${PASSWORD}" ]; then
    echo "Usage: matrix-create-admin.sh <username> <password>"
    echo "Beispiel: matrix-create-admin.sh admin MeinSicheresPasswort123"
    exit 1
fi

echo "Erstelle Admin-User: @${USERNAME}:$(grep '^server_name:' ${SYNAPSE_CONFIG} | awk '{print $2}' | tr -d '"')"

/opt/synapse/bin/register_new_matrix_user \
    --config "${SYNAPSE_CONFIG}" \
    --user "${USERNAME}" \
    --password "${PASSWORD}" \
    --admin \
    -c "${SYNAPSE_CONFIG}"

echo ""
echo "✅ Admin-User erstellt!"
echo ""
echo "Synapse Admin UI: http://[HA-IP]:8090"
echo "Homeserver URL für Admin UI: http://localhost:8008"
echo "Login: @${USERNAME}:$(grep '^server_name:' ${SYNAPSE_CONFIG} | awk '{print $2}' | tr -d '"')"
