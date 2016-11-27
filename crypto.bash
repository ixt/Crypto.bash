#!/usr/bin/env bash

# NfN Orange
# Crypto "library" for bash
# Cyphertext = Plaintext^Publickey % (Public*Private)
# Plaintext = Cyphertext^Privatekey % (Public*Private)

# key strength >32000 is default
# strength resolves at 100 pretty well
# changes the maximum value of the primes
STRENGTH=100

isVerbose=0

verbose(){
    if [[ $isVerbose -eq 1 ]]; then
        echo "$@" 1>&2;
    else
        echo "$@" >/dev/null
    fi
}

# my primes are probable primes
function isPrime(){
    # Take interger check if its a prime via
    # Fermat's little theorm like
    # Miller-Rabin primality test
    # Adapted partially from here:
    # https://en.wikipedia.org/wiki/Primality_test
    local n=$1
    local d=$(($n - 1))

    # first few numbers in cases for speed
    local accuracy=$2
    if [[ $n -lt 6 ]]; then
        case $n in
            0) shift
                return 0
                ;;
            1) shift
                return 0
                ;;
            2) shift
                return 1
                ;;
            3) shift
                return 1
                ;;
            4) shift
                return 0
                ;;
            5) shift
                return 1
                ;;
        esac
    elif [[ $(( $n % 2 )) -eq 0 ]]; then
        # is it even?
        return 0
    else
        local lastno=$(echo $n | grep -o '.$')
        if [[ $lastno -eq 5 ]]; then
            # is it divisable by 5
            return 0
        fi
        local count=$accuracy
        while (( $count != 0 )); do
            local a=$(( ($RANDOM * $RANDOM ) % ($n - 2) ))
            # a^d mod n
            local STEP=$( echo "scale=0;($a ^ $d) % $n" | bc -l | sed -e 's/\\//g')
            verbose "( $a ^ $d ) % $n"
            if [[ $STEP != 1 && $a != 0 ]]; then
                return 0
            fi
            (( count-- ))
        done
        return 1
    fi
}

# Bash doesnt have GCD so here is Euclid's GCD Algo
# Adapted from a Java Method found here:
# http://people.cs.ksu.edu/~schmidt/301s12/Exercises/euclid_alg.html

gcd(){
    local k=$1
    local m=$2

    while (( $k != $m )); do
        if (( $k > $m )); then
            local K=$(($k-$m))
            # verbose "k!" $k - $m
            k=$K
        else
            local M=$(($m - $k))
            # verbose "m!" $m - $k
            m=$M
        fi
    done
    return $k
}

generateKeyPair(){
    # generate 2 primes
    # this takes a reading from /dev/random
    # the random numbers are then checked for primality
    local p=$RANDOM%$STRENGTH
    local q=$RANDOM%$STRENGTH
    local p_iscomposite=true
    local q_iscomposite=true
    while $p_iscomposite; do
        local oldp=$p
        p=$(( $oldp - 1 ))
        if [[ "$p" -lt "11" ]]; then
            p=$STRENGTH
        fi
        isPrime $p 20
        if [[ $? -eq 1 ]]; then
            p_iscomposite=false
            verbose "p = $p"
        fi
    done
    while $q_iscomposite; do
        local oldq=$q
        q=$(( $oldq - 1 ))
        if [[ "$q" -lt "11" ]]; then
            q=$STRENGTH
        fi
        isPrime $q 20
        if [[ $? -eq 1 ]]; then
            if [[ $q != $p ]]; then
                q_iscomposite=false
                verbose "q = $q"
            fi
        fi
    done
    local nonce=$(($p * $q))
    local phi=$(( ($p -1) * ($q - 1)))
    local e=0
    local E=1
    # by properly checking the public exponent
    # it -should- make it more secure than just using
    # 3 or 65537, provided it is larger than 65537
    while (( $e != $E )); do
        e=$((($RANDOM * $RANDOM) % $phi ))
        gcd $e $phi
        local returned=$?
        if [[ $returned -eq 1 ]]; then
            E=$e
            verbose "e is $e"
        fi
    done
    # Modular inverse
    # Determine d = e^-1(mod phi)
    # I couldnt get my adapted modular inverse to produce things correctly
    # but i found a "broken" C++ and ported to bash/bc
    # Found here:
    # http://www.codeproject.com/Questions/608403/RSAplusKeyplusgenerationplusinplusC-b-b
    local k=0
    d=$(echo "scale=0;(1+($k*$phi))/$e" | bc -l)
    _d=$(echo "scale=0;(1+($k*$phi))%$e" | bc -l)
    while (( $_d != 0)); do
        (( k++ ))
        verbose "no to $d (1+($k*$phi))/$e"
        d=$(echo "scale=0;(1+($k*$phi))/$e" | bc -l)
        _d=$(echo "scale=0;(1+($k*$phi))%$e" | bc -l)
    done
    verbose "sucess with $d (1+($k*$phi))/$e"
    verbose "p is $p, q is $q, phi is $phi"
    PUBLIC_KEY=$(echo "e$e""n$nonce")
    PRIVATEKEY=$(echo "d$d""n$nonce")
    OUTPUT=$(echo "e$e""d$d""n$nonce")
}

encryptString(){
    # c = m^e (mod n)
    k=$(echo $1 | grep -o .)
    readingE=1
    local c
    local e
    local n
    for char in ${k[@]}; do
        if [[ $char == "e" ]]; then
            readingE=1
            continue
        elif [[ $char == 'n' ]]; then
            readingE=0
            continue
        fi
        if [[ $readingE -eq 1 ]]; then
            e=$e$char
        else
            n=$n$char
        fi
    done
    verbose Encryption key: $e
    verbose Nonce $n
    m=$(echo "$2" | xxd -p)
    echo $m | sed -e "s/ /\n/g" -e "s/.\{2\}/&\n/g" > .tempfile
    while read entry; do
        if [[ -n "$entry" ]]; then
            verbose Clear block: $entry
            dec=$(printf "%d\n" 0x$entry)
            block=$(echo "scale=0;($dec ^ $e) % $n" | bc -l | sed -e "s/[\]//g")
            hblock=$(printf "%x\n" $block)
            c=$(echo $c" "$hblock)
            verbose Cypher block: $hblock
        fi
    done < .tempfile
    if [[ $isVerbose != 1 ]]; then
        rm .tempfile
    fi
    echo $c
}

decryptString(){
    # m = c^d (mod n)
    k=$(echo $1 | grep -o .)
    readingD=1
    local m
    local d
    local n
    for char in ${k[@]}; do
        if [[ $char == "d" ]]; then
            readingD=1
            continue
        elif [[ $char == 'n' ]]; then
            readingD=0
            continue
        fi
        if [[ $readingD -eq 1 ]]; then
            d=$d$char
        else
            n=$n$char
        fi
    done
    echo $2 | sed -e "s/ /\n/g"> .tempfile
    while read entry; do
        verbose Cypher block: $entry
        if [[ -n "$entry" ]]; then
            dec=$(printf "%d\n" 0x$entry)
            block=$(echo "scale=0;($dec ^ $d) % $n" | bc -l | sed -e "s/[\]//g")
            hblock=$(printf "%x\n" $block)
            if [ ${#hblock} == 1 ]; then
                hblock=0$hblock
            fi
            m=$m$hblock
            verbose Clear block: $hblock
        fi
    done < .tempfile
    message=$(echo $m | xxd -r -ps)
    if [[ $isVerbose != 1 ]]; then
        rm .tempfile
    fi
    echo $message
}


while [ "$#" -gt 0 ]; do
    case "$1" in
           --verbose|-v)
            isVerbose=1
            ;;
        --gen|-g) shift
            generateKeyPair
            verbose "Public:" "$PUBLIC_KEY"
            verbose "Private:" "$PRIVATEKEY"
            if [ $isVerbose != 1 ]; then
                echo $OUTPUT
            fi
            ;;
        --encrypt|-e) shift
            encryptString "$1" "$2"
            verbose Encrypted
            shift
            ;;
        --decrypt|-d) shift
            decryptString "$1" "$2"
            verbose Decrypted
            shift
            ;;
        *) shift
            echo "crypto.bash - v0.1 NfN Orange CC0"
            echo "g[en]     generates a key pair"
            echo "e[ncrypt] encrypts a string to a given public key"
            echo "d[ecrypt] decrypts a string to a given private key"
            echo "Don't use this for anything serious, this is educational not for good practise"
            exit -1
            ;;
    esac
    shift
done
