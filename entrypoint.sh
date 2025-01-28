#!/bin/sh

_strip_name() {
    echo "$1" | tr '@&+.:' '-' | tr -d '=!%^#$\/()[]{}|;<>, ' | xargs
}

set -- "$1" "$(_strip_name "$2")" "$3"
if [ -z "$2" ]; then
    set -- "$1" 'socks' "$3"
fi

# Set default port if not provided
PORT=${PORT:-18989}
WORKERS=${WORKERS:-10}
CONFIG="/srv/dante.conf"
ETH=${ETH:-eth0}
DEFAULT_DANTE_USER=${DEFAULT_DANTE_USER:-user}
DEFAULT_DANTE_USER_PASSWORD=${DEFAULT_DANTE_USER_PASSWORD:-p4ZNcBXvw5IIygQN}

# Replace port placeholder in dante.conf
sed -i "s/__PORT__/$PORT/g" "/srv/dante.conf"
# Replace eth placeholder in dante.conf
sed -i "s/__ETH__/$ETH/g" "/srv/dante.conf"

# shellcheck disable=SC2016
HELP='Usage: /entrypoint.sh [COMMAND [PARAMS..]]

Commands:
    add-user NAME [PASS]    Add a new user
    del-user NAME           Delete an existing user
    start                   Start the dante server
                            [container command]

Parameters:
    NAME                    A username
                            [default: "socks"]
'

case "$1" in
    'add-user')
        USER="$2"
        PASS=$(echo "$3" | xargs)
        if [ -z "$PASS" ]; then
            PASS=$(openssl rand -base64 16)
        fi

        adduser --quiet --system --no-create-home "$USER"
        echo "$USER:$PASS" | chpasswd

        URL="http://ifconfig.co"
        HOST=$(curl -s "$URL")

        echo 'SOCKS5 connection parameters:'
        echo "- Server:   $HOST:$PORT"
        echo "- Username: $USER"
        echo "- Password: $PASS"
        echo
        echo 'Test it using the following command:'
        echo "curl --socks5 $USER:$PASS@$HOST:$PORT -L $URL"
        ;;
    'del-user')
        deluser --quiet --system "$2" 2> /dev/null
        ;;
    'start')
        # Check if user exists. If not, create it
        if ! id -u $DEFAULT_DANTE_USER > /dev/null 2>&1; then
            adduser --quiet --system --no-create-home $DEFAULT_DANTE_USER
            # default password for user is p4ZNcBXvw5IIygQN
            echo "$DEFAULT_DANTE_USER:$DEFAULT_DANTE_USER_PASSWORD" | chpasswd
        fi
        danted -N "$WORKERS" -f "$CONFIG"
        ;;
    *)
        echo "$HELP"
        ;;
esac
