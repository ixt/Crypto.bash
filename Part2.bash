#!/usr/bin/env bash

# Clean the enviroment setting all vars to defaults

# -------------------
# Pretty-fy Functions
# -------------------

BOLD=$(tput bold)
UNDERLINE=$(tput sgr 0 1)
RESET=$(tput sgr0)

PURPLE=$(tput setaf 171)
RED=$(tput setaf 1)
BLUE=$(tput setaf 76)
TAN=$(tput setaf 3)
GREEN=$(tput setaf 38)

NAMES="${BOLD}${TAN}S${RESET}"
NAMEA="${BOLD}${GREEN}A${RESET}"
NAMEB="${BOLD}${BLUE}B${RESET}"

# -----
# Setup
# -----

do_setup_enviroment() {
    ALICE_INBOX="Nothing here yet"
    ALICE_ENCKEY="Nothing here yet"
    ALICE_PRIKEY="d683n2059"
    ALICE_NONCE_STORAGE=""
    BOB_ENCKEY="Nothing here yet"
    BOB_PRIKEY="d1913n2021"
    BOB_INBOX="Nothing here yet"
    BOB_NONCE_STORAGE=""
    SERVER_PRIKEY="d3333n3901"
    SERVER_PUBKEY="e885n3901"
    SERVER_INBOX="Nothing here yet"
    SERVER_OUTBOX="Nothing here yet"
    SERVER_KEYFILE="./keys.csv"
}

SERVER_ENCKEY=""
get_key(){
    NAME=$1
    SERVER_ENCKEY=""
    local KEY
    echo "What is $NAME's key"
    while read entry; do
        name=$(echo $entry | cut -d"," -f 1 | sed -e "s/\"//g")
        if [ "$name" == "$NAME" ]; then
            SERVER_ENCKEY=$(echo $entry | cut -d"," -f2 | sed -e "s/\"//g")
        fi
    done < $SERVER_KEYFILE
    echo "$NAME's public key is $SERVER_ENCKEY"
}

fetch_key(){
    NAME=$1
    RECIPENT=$2
    ADDRESS=$3
    FOUND_ASK_KEY=$(get_key $1)
    FOUND_ASKER_KEY=$(get_key $2)
    make_message $SERVER_PRIKEY "Here is $1's key: $FOUND_KEY" "S" $2
}

MESSAGE=""
make_message(){
    # Erase message
    MESSAGE=""
    # Set vars
    local KEY=$1
    local REQUEST=$2
    NAME=$3
    TARGET=$4
    local SIGNKEY=$(echo $5 | sed -e "s/d/e/")
    PLAIN=$(echo -e "$TARGET, \"$NAME\", $REQUEST")
    echo "Encrypting: \"$PLAIN\" with $1 signed $SIGNKEY"
    CYPHER=$(./crypto.bash e $KEY "$PLAIN")
    SIG=$(./crypto.bash e $SIGNKEY "$PLAIN")
    MESSAGE=$(echo "$CYPHER sig $SIG")
    echo "Cypher text: $MESSAGE"
}

do_decrypt(){
    echo "WARNING NO SIG DECRYPT"
    PRIKEY=$1
    INPUT=$2
    CYPHER_MSG=$(echo $INPUT | sed -e "s/sig.*//g")
    echo "CYPHER MSG: $CYPHER_MSG"
    CLE_MESSAGE=$(./crypto.bash d $PRIKEY "$CYPHER_MSG")
    echo "Decrypted Message: $CLE_MESSAGE"
    MESSAGE="$CLE_MESSAGE"
}

SIGNER=""
SERVER_INBOX=""
REALSIGNER=0
do_server_check_sig(){
    SIGNER=""
    MESSAGE=$1
    CYPHER_SIG=$(echo $MESSAGE | sed -e "s/.*sig//g")
    echo "CYPHER SIG: $CYPHER_SIG"
    CYPHER_MSG=$(echo $MESSAGE | sed -e "s/sig.*//g")
    echo "CYPHER MSG: $CYPHER_MSG"

    CLE_MESSAGE=$(./crypto.bash d $SERVER_PRIKEY "$CYPHER_MSG")
    echo "Decrypted Message: $CLE_MESSAGE"

    SIGNER=$(echo "$CLE_MESSAGE" | cut -d"," -f 2 | sed -e "s/\"//g")
    get_key $SIGNER
    UNSIGNKEY=$(echo $SERVER_ENCKEY | sed -e "s/e/d/g")
    SIG_MESSAGE=$(./crypto.bash d $UNSIGNKEY "$CYPHER_SIG")

    echo "Signed Output: $SIG_MESSAGE"
    if [[ "$SIG_MESSAGE" == "$CLE_MESSAGE" ]]; then
        REALSIGNER=1
        echo "Signature for $NAME is correct!"
        SERVER_INBOX="$CLE_MESSAGE"
    else
        REALSIGNER=0
    fi
}

do_request(){
    INPUT=$(echo "$1" | cut -d"," -f 3 | sed -e "s/REQ//g")
    OUTPUT=$(echo "$1" | cut -d"," -f 2 | sed -e "s/\"//g")
    get_key $INPUT
    SERVER_OUTBOX="$SERVER_ENCKEY"
    get_key $OUTPUT
    make_message $SERVER_ENCKEY "$SERVER_OUTBOX" "server" "output" "$SERVER_PRIKEY"
    SERVER_OUTBOX="$MESSAGE"
}

do_check_sig(){
    REALSIGNER=0
    CHECKKEY=$1
    PRIKEY=$2
    INPUT=$3

    CYPHER_SIG=$(echo $INPUT | sed -e "s/.*sig//g")
    echo "CYPHER SIG: $CYPHER_SIG"
    CYPHER_MSG=$(echo $INPUT | sed -e "s/sig.*//g")
    echo "CYPHER MSG: $CYPHER_MSG"

    CLE_MESSAGE=$(./crypto.bash d $PRIKEY "$CYPHER_MSG")
    echo "Decrypted Message: $CLE_MESSAGE"

    UNSIGNKEY=$(echo $CHECKKEY | sed -e "s/e/d/g")
    SIG_MESSAGE=$(./crypto.bash d $UNSIGNKEY "$CYPHER_SIG")

    echo "Signed Output: $SIG_MESSAGE"
    if [[ "$SIG_MESSAGE" == "$CLE_MESSAGE" ]]; then
        REALSIGNER=1
        echo "Signature for $NAME is correct!"
        MESSAGE="$CLE_MESSAGE"
    else
        REALSIGNER=0
    fi
}

do_changevar(){
    eval "$1=\"$2\""
}

do_setup_enviroment
# -----------
# Run Example
# -----------
printf "${GREEN} Dear $NAMES${GREEN}, This is $NAMEA${GREEN} and I would like $NAMEB${GREEN}’s public key. Yours sincerely, $NAMEA${GREEN}.${RESET}\n"
#  Dear S, This is A and I would like to get B’s public key. Yours sincerely, A.
make_message $SERVER_PUBKEY "REQ bob" "alice" "server" $ALICE_PRIKEY
SERVER_INBOX="$MESSAGE"
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

# Check Sigs
echo "Server recieved message: $SERVER_INBOX"
echo "Decrypting and Verifying New message"
do_server_check_sig "$SERVER_INBOX"
if [[ $REALSIGNER -eq 0 ]]; then
    "WRONG SIG"
    exit 0
fi

#  Dear A, Here is B’s public key signed by me. Yours sincerely, S.
printf "${TAN} Dear $NAMEA${TAN}, Here is $NAMEB${TAN}’s public key signed by me. Yours sincerely, $NAMES${TAN}.${RESET}\n"
do_request "$SERVER_INBOX"
ALICE_INBOX="$SERVER_OUTBOX"
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

# Check Sigs
echo "Alice recieved message: $ALICE_INBOX"
do_check_sig $SERVER_PUBKEY $ALICE_PRIKEY "$ALICE_INBOX"
ALICE_ENCKEY=$(echo $MESSAGE | cut -d"," -f3)
echo "Alice Got Bob's key: $ALICE_ENCKEY"

#  Dear B, This is A and I have sent you a nonce only you can read. Yours sincerely, A.
printf "${GREEN} Dear $NAMEB${GREEN}, This is $NAMEA${GREEN} and I have sent you a nonce only you can read. Yours sincerely, $NAMEA${GREEN}.${RESET}\n"
make_message $ALICE_ENCKEY "\"A23\"" "alice" "bob" $ALICE_PRIKEY
BOB_INBOX="$MESSAGE"
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

# Check sigs
echo "Bob recieved Message: $BOB_INBOX"
do_decrypt $BOB_PRIKEY "$BOB_INBOX"

BOB_NONCE_STORAGE=$(echo "$MESSAGE" | cut -d"," -f3 | sed -e "s/\"//g" )
echo "Bob's Nonce Storage is now $BOB_NONCE_STORAGE"

printf "${BLUE} Dear $NAMES${BLUE}, This is $NAMEB${BLUE} and I would like $NAMEA${BLUE}’s public key. Yours sincerely, $NAMEB${BLUE}.${RESET}\n"
#  Dear S, This is B and I would like to get A’s public key. Yours sincerely, B.
make_message $SERVER_PUBKEY "REQ alice" "bob" "server" $BOB_PRIKEY
SERVER_INBOX="$MESSAGE"
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

# Check sigs
echo "Server recieved message: $SERVER_INBOX"
echo "Decrypting and Verifying New message"
do_server_check_sig "$SERVER_INBOX"
if [[ $REALSIGNER -eq 0 ]]; then
    "WRONG SIG"
    exit 0
fi

printf "${TAN} Dear $NAMEB${TAN}, Here is $NAMEA${TAN}’s public key signed by me. Yours sincerely, $NAMES${TAN}.${RESET}\n"
do_request "$SERVER_INBOX"
BOB_INBOX="$SERVER_OUTBOX"
#  Dear B, Here is A’s public key signed by me. Yours sincerely, S.
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

# Check sigs
echo "Bob recieved message: $BOB_INBOX"
do_check_sig $SERVER_PUBKEY $BOB_PRIKEY "$BOB_INBOX"
BOB_ENCKEY=$(echo $MESSAGE | cut -d"," -f3 )
echo "Bob Got Alice's key: $BOB_ENCKEY"

printf "${BLUE} Dear $NAMEA${BLUE}, Here is my nonce and yours, proving I decrypted it. Yours sincerely, $NAMEB${BLUE}.${RESET}\n"
#  Dear A, Here is my nonce and yours, proving I decrypted it. Yours sincerely, B.
make_message $BOB_ENCKEY "\"B42 & $BOB_NONCE_STORAGE\"" "bob" "alice" $BOB_PRIKEY
ALICE_INBOX="$MESSAGE"
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

# Check Sigs
echo "Alice recieved message: $ALICE_INBOX"
do_check_sig $ALICE_ENCKEY $ALICE_PRIKEY "$ALICE_INBOX"
ALICE_NONCE_STORAGE=$(echo "$MESSAGE" | cut -d"," -f3)

printf "${GREEN} Dear $NAMEB${GREEN}, Here is your nonce proving I decrypted it. Yours sincerely, $NAMEA${GREEN}.${RESET}\n"
#  Dear B, Here is your nonce proving I decrypted it. Yours sincerely, A.
make_message $ALICE_ENCKEY "$ALICE_NONCE_STORAGE" "alice" "bob" $ALICE_PRIKEY
BOB_INBOX="$MESSAGE"
printf "${BOLD}${RED} Press Enter Key${RESET}"
read > /dev/zero

