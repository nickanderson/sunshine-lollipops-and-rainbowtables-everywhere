#!/usr/bin/env bash
# Author: Nick Anderson <nick@cmdln.org>
# Brief: Generate unique password hashes for each Incoming host in CFEngine
#        lastseen database
# Description: Designed as a prototype for use with the shortcut feature in
#              CFEngine access type promises combined with server side
#              expansion of the connection.key variable.

HASHED_OUTPUT_DIR="/var/cfengine/cmdb/"
HASHED_OUTPUT_FILENAME="root.hash"

STORE_PLAINTEXT=false
PLAINTEXT_OUTPUT_DIR="${HASHED_OUTPUT_DIR}"
PLAINTEXT_OUTPUT_FILENAME="root.plaintext"

# Turn off echo in POSIX compliant way so we don't see the password as typed in
unset PASSWORD
unset CHARCOUNT

echo -n "Enter password: "

stty -echo

CHARCOUNT=0
while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
do
    # Enter - accept password
    if [[ $CHAR == $'\0' ]] ; then
        break
    fi
    # Backspace
    if [[ $CHAR == $'\177' ]] ; then
        if [ $CHARCOUNT -gt 0 ] ; then
            CHARCOUNT=$((CHARCOUNT-1))
            PROMPT=$'\b \b'
            PASSWORD="${PASSWORD%?}"
        else
            PROMPT=''
        fi
    else
        CHARCOUNT=$((CHARCOUNT+1))
        PROMPT='*'
        PASSWORD+="$CHAR"
    fi
done

stty echo

# What hasing algorithm do I support?
# for EL5 consider `authconfig --passalgo=sha512 --update`
#HASHING_ALGORITHM=$(authconfig --test | awk '/hashing/ { print $NF } ')
#echo $HASHING_ALGORITHM

printf "
1. MD5 (Default RHEL 5)
2. Blowfish
5. SHA-256
6. SHA-512

Please choose a valid password hasing algorithm [1|2|5|6]"
while [[ ! ${_algo} =~ ^[1256]+$ ]]; do
    echo "Please enter a valid selection: "
    read -r _algo
done
export _algo=$_algo

# Host identifiers to generate keys for
# Data could be sourced from a simple file, an API call to CFEngine Enterprise
# Mission Portal

# By ppkey sha
HOSTS=$(cf-key -s | awk '/Incoming/ { print $NF }')

# Simple: Unqualified host name $(sys.uqhost)
# HOSTS=(host001 host002 host003)

#########################################################################################################

HOST_COUNT=${#HOSTS[@]}
echo "Generating unique password hashes for all 'Incoming' hosts that are present in the lastseen database"
echo "Note: By default hosts not seen within 7 days are purged from the lastseen database."

echo "Host Count: $HOST_COUNT"
echo "$HOSTS"
COUNT=1
for each in $HOSTS; do
    echo "Generating Unique Hash for $each"

    mkdir -p "$HASHED_OUTPUT_DIR/$each" &> /dev/null
    export _salt
    _salt=$(openssl rand 1000 | strings | grep -io '[0-9A-Za-z\.\/]' | head -n 16 | tr -d '\n' )
    export _password=$PASSWORD

    perl -e 'print crypt("$ENV{'_password'}","\$$ENV{'_algo'}\$"."$ENV{'_salt'}"."\$\n")' > "${HASHED_OUTPUT_DIR}/${each}/$HASHED_OUTPUT_FILENAME" && echo "Wrote hash for ${each} to ${HASHED_OUTPUT_DIR}/${each}/${HASHED_OUTPUT_FILENAME}" && COUNT=$((COUNT+1))
    # Useful if you want to store the plaintext version for reference

    if [ "${STORE_PLAINTEXT}" = true ]; then
      echo "$PASSWORD" > "${PLAINTEXT_OUTPUT_DIR}/${each}/${PLAINTEXT_OUTPUT_FILENAME}"
    fi

    unset _password
    unset PASSWORD
    unset _salt
done

echo "Generated $COUNT unique password hashes in $HASHED_OUTPUT_DIR of $HOST_COUNT hosts seen in lastseen database."
