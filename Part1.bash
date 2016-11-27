#!/usr/bin/env bash

# This utility requires whiptail, bc, grep, sed, xxd, bash
# most of which are usually installed on a linux system

# a good width for whiptail

calc_whiptail_size(){
    WT_HEIGHT=20
    WT_WIDTH=$(tput cols)
    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 50 ]; then
        WT_WIDTH=60
    fi
    if [ "$WT_WIDTH" -gt 80 ]; then
        WT_WIDTH=80
    fi
    WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}


# Clean the enviroment setting all vars to none
do_setup_enviroment() {
    ALICE_PLAIN="Nothing here yet"
    ALICE_CYPHER="Nothing here yet"
    ALICE_INBOX="Nothing here yet"
    ALICE_PUBKEY="Nothing here yet"
    ALICE_PRIKEY="Nothing here yet"
    BOB_PLAIN="Nothing here yet"
    BOB_CYPHER="Nothing here yet"
    BOB_PUBKEY="Nothing here yet"
    BOB_PRIKEY="Nothing here yet"
    BOB_INBOX="Nothing here yet"
}

do_show_enviroment(){
    whiptail --title "Enviroment" --msgbox "\
     Alice Plain-text : $ALICE_PLAIN \n \
    Alice Cypher-test: $ALICE_CYPHER \n \
    Alice Inbox      : $ALICE_INBOX \n \
    Alice Public Key : $ALICE_PUBKEY \n \
    Alice Private Key: $ALICE_PRIKEY \n \
    Bob Plain-text   : $BOB_PLAIN \n \
    Bob cypher-text  : $BOB_CYPHER \n \
    Bob Public key   : $BOB_PUBKEY \n \
    Bob Private key  : $BOB_PRIKEY \n \
    Bob Inbox        : $BOB_INBOX \n \
    " 20 70
}

do_message(){
    NAME=$1
    TARGET=$2
    # Get Plain Text
    PLAIN=$(whiptail --inputbox "Hi $NAME, what would you like to send to $TARGET?" 20 70 --title "Send a message" 3>&1 1>&2 2>&3)
    i=\$"$3"
    _i=`eval "expr \"$i\" "`
    eval "$3=\"$PLAIN\""
    j=\$"$4"
    _j=`eval "expr \"$j\" "`
    eval "$4=\"$PLAIN\""
}



do_genkeys(){
    gen_key Bob BOB_PRIKEY BOB_PUBKEY
    gen_key Alice ALICE_PRIKEY ALICE_PUBKEY
}

gen_key(){
    # This generates a key using my crypto.bash then parses the output to sort
    # them into the correct variables
    WHO=$1
    echo "Generating $WHO's keys"
    local key=$(./crypto.bash -g | grep -o .)
    echo $key | sed -e "s/ //g"
    local e
    local d
    local n
    readingType=0
    for char in ${key[@]}; do
        case "$char" in
            e ) readingType=0; continue ;;
            d ) readingType=1; continue ;;
            n ) readingType=2; continue ;;
            * ) \
               case "$readingType" in
                   0 ) e=$e$char ;;
                   1 ) d=$d$char ;;
                   2 ) n=$n$char ;;
               esac
       esac
    done
    PRIKEY=$(echo "d"$d"n"$n)
    PUBKEY=$(echo "e"$e"n"$n)
    i=\$"$2"
    _i=`eval "expr \"$i\" "`
    eval "$2=\"$PRIKEY\""
    i=\$"$3"
    _i=`eval "expr \"$i\" "`
    eval "$3=\"$PUBKEY\""
}

do_encrypt(){
    local KEY=$1
    NAME=$4
    TARGET=$5
    # Get Plain Text
    PLAIN=$(whiptail --inputbox "Hi $NAME, what would you like to send to $TARGET?" 20 70 1 --title "Send a message" 3>&1 1>&2 2>&3)
    CYPHER=$(./crypto.bash -e $KEY "$PLAIN")
    # Some Pointery stuff
    i=\$"$2"
    _i=`eval "expr \"$i\" "`
    eval "$2=\"$CYPHER\""
    i=\$"$3"
    _i=`eval "expr \"$i\" "`
    eval "$3=\"$CYPHER\""
}

do_decrypt(){
    local KEY=$1
    i=\$"$2"
    _i=`eval "expr \"$i\" "`
    if [ "$_i" == "Nothing here yet" ]; then
        whiptail "Nothing in Bob's Inbox" 20 20 1
        return
    fi
    PLAIN=$(./crypto.bash -d $KEY "$_i")
    eval "$3=\"$PLAIN\""
}

# ---------------------------------
# ONLY TUI STUFF BEFORE
# ---------------------------------

# ----------------
# Variable Reading
# ----------------
# Charlie can only read the inboxes of the others

do_charlie(){
    whiptail --msgbox " \
        Alice's inbox = $ALICE_INBOX \n \
        Bob's inbox   = $BOB_INBOX \n \
        " 20 70
}

do_readvar(){
    i=\$"$1"
    _i=`eval "expr \"$i\" "`
    whiptail --msgbox "$_i" 20 70
}

# ----------------
# Menus
# ----------------

do_example(){
     MENU=$(whiptail --menu "options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select\
        "0  Generate Keys" "DO THIS FIRST" \
        "1  Alice Out" "Write Message, Encrypt and send to Bob" \
        "2  Charlie" "Read Alice and Bobs inbox!"\
        "3  Bob Decrypt" "Decrypt Bob's Inbox (and put it in Bob's Plain Text)" \
        "4  Bob Read" "Read Bob's Plain Text" \
        "5  Charlie" "Read Alice and Bobs inbox!"\
        "6  Bob Out" "Write Message, Encrypt and send to Alice" \
        "7  Charlie" "Read Alice and Bobs inbox!"\
        "8  Alice Decrypt" "Decrypt Alice's Inbox (and put it in Alice's Plain Text)" \
        "9  Charlie" "Read Alice and Bobs inbox!"\
        "10  Alice Read" "Read Alice's Plain Text" \
    3>&1 1>&2 2>&3)
     case "$MENU" in
        0\ *) do_genkeys; do_example ;;
        1\ *) do_encrypt $BOB_PUBKEY "BOB_INBOX" "ALICE_CYPHER" Alice Bob; do_example ;;
        2\ *) do_charlie; do_example ;;
        3\ *) do_decrypt $BOB_PRIKEY "BOB_INBOX" "BOB_PLAIN"; do_example ;;
        4\ *) do_readvar "BOB_PLAIN"; do_example;;
        5\ *) do_charlie; do_example ;;
        6\ *) do_encrypt $ALICE_PUBKEY "ALICE_INBOX" "BOB_CYPHER" Bob Alice; do_example ;;
        7\ *) do_charlie; do_example ;;
        8\ *) do_decrypt $ALICE_PRIKEY "ALICE_INBOX" "ALICE_PLAIN"; do_example  ;;
        9\ *) do_charlie; do_example ;;
        10\ *) do_readvar  "ALICE_PLAIN"; do_example ;;
            *) return 0;;
        esac || return 0
}

do_plain_message(){
    MENU=$(whiptail --menu "options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select\
        "1  Alice Out" "Write Message and send to Bob" \
        "2  Alice Read" "Read Alice's Inbox" \
        "3  Bob Out" "Write Message and send to Alice" \
        "4  Bob Read" "Read Bob's Inbox" \
        "5  Charlie" "Read Alice and Bobs inbox!"\
    3>&1 1>&2 2>&3)
    case "$MENU" in
        1\ *) do_message Alice Bob BOB_INBOX ALICE_PLAIN; do_plain_message ;;
        2\ *) do_readvar ALICE_INBOX; do_plain_message ;;
        3\ *) do_message Bob Alice ALICE_INBOX BOB_PLAIN; do_plain_message ;;
        4\ *) do_readvar BOB_INBOX; do_plain_message ;;
        5\ *) do_charlie; do_plain_message ;;
            *) return 0 ;;
        esac || return 0
}

do_secure_message(){
    MENU=$(whiptail --menu "options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select\
        "0  Generate Keys" "DO THIS FIRST" \
        "1  Alice Out" "Write Message, Encrypt and send to Bob" \
        "2  Alice Decrypt" "Decrypt Alice's Inbox (and put it in Alice's Plain Text)" \
        "3  Alice Read" "Read Alice's Plain Text" \
        "4  Bob Out" "Write Message, Encrypt and send to Alice" \
        "5  Bob Decrypt" "Decrypt Bob's Inbox (and put it in Bob's Plain Text)" \
        "6  Bob Read" "Read Bob's Plain Text" \
        "7  Charlie" "Read Alice and Bobs inbox!"\
    3>&1 1>&2 2>&3)
    case "$MENU" in
        0\ *) do_genkeys; do_secure_message ;;
        1\ *) do_encrypt $BOB_PUBKEY "BOB_INBOX" "ALICE_CYPHER" Alice Bob; do_secure_message  ;;
        2\ *) do_decrypt $ALICE_PRIKEY "ALICE_INBOX" "ALICE_PLAIN"; do_secure_message  ;;
        3\ *) do_readvar  $ALICE_PLAIN; do_secure_message  ;;
        4\ *) do_encrypt $ALICE_PUBKEY "ALICE_INBOX" "BOB_CYPHER" Bob Alice; do_secure_message  ;;
        5\ *) do_decrypt $BOB_PRIKEY "BOB_INBOX" "BOB_PLAIN"; do_secure_message  ;;
        6\ *) do_readvar $BOB_PLAIN; do_secure_message  ;;
        7\ *) do_charlie; do_secure_message  ;;
            *) return 0 ;;
        esac || return 0
}

# ----------------
# Setup
# ----------------

calc_whiptail_size
do_setup_enviroment

# ----------------
# Application loop
# ----------------

while true; do
    MENU=$(whiptail --title "Crypto.bash" --menu "options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select\
        "1 Example" "Example conversation, guided" \
        "2 Insecure Communication" "Manual Plain Text Sending " \
        "3 Secure Communication" "Manual Cypher Text Sending " \
        "4 Show" "Show envrioment variables" \
        "5 Clean Enviroment" "Reset Enviroment to starting state" \
        3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        exit 0
    elif [ $RET -eq 0 ]; then
        case "$MENU" in
            1\ *) do_example ;;
            2\ *) do_plain_message ;;
            3\ *) do_secure_message ;;
            4\ *) do_show_enviroment ;;
            5\ *) do_setup_enviroment ;;
            *) exit 1 ;;
        esac || return 0
    else
        exit 1
    fi
done
