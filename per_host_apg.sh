#!/bin/bash
# Author: Nick Anderson <nick@cmdln.org>
# Brief: Generate unique password hashes for each Incoming host in CFEngine
#        lastseen database
# Description: Designed as a prototype for use with the shortcut feature in
#              CFEngine access type promises combined with server side
#              expansion of the connection.key variable.

OUTPUT_DIR="/var/cfengine/cmdb/"
OUTPUT_FILE="root.hash"

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

# Replace with api call to MP?
HOSTS=$(cf-key -s | awk '/Incoming/ { print $NF }')
#HOSTS=(host001 host002 host003)
HOST_COUNT=${#HOSTS[@]}
#$(cf-key -s | grep -c "Incoming")
echo "Generating unique password hashes for all 'Incoming' hosts that are present in the lastseen database"
echo "Note: By default hosts not seen within 7 days are purged from the lastseen database."

echo "Host Count: $HOST_COUNT"
echo "$HOSTS"
COUNT=1
for each in $HOSTS; do
    echo "Generating Unique Hash for $each"

    mkdir -p "$OUTPUT_DIR/$each" &> /dev/null
    export _salt
    _salt=$(openssl rand 1000 | strings | grep -io '[0-9A-Za-z\.\/]' | head -n 16 | tr -d '\n' )
    echo "Generating host specific password"
    export _password
    _password=$(apg -a 1 -m 63 -n 1)
    perl -e 'print crypt("$ENV{'_password'}","\$$ENV{'_algo'}\$"."$ENV{'_salt'}"."\$\n")' > "$OUTPUT_DIR/$each/$OUTPUT_FILE" && echo "Wrote unique password hash for $each to $OUTPUT_DIR/$each/$OUTPUT_FILE" && COUNT=$((COUNT+1))
    echo "Password: $_password"
    echo "$_password" > "$OUTPUT_DIR/$each/$OUTPUT_FILE.plaintext"
    unset _password
    # Useful if you want to store the plaintext version for reference
    unset _salt
done

echo "Generated $COUNT unique password hashes in $OUTPUT_DIR of $HOST_COUNT hosts seen in lastseen database."
