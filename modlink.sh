#!/bin/bash

: << LICENSE

MIT License

Copyright (c) 2018 Vitalii Bieliavtsev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

LICENSE

# Variables
DIALOG=${DIALOG=dialog}
INSTALLED_LIST=$(tempfile 2>/dev/null) || tempfile=/tmp/test$$
tempfile=$(tempfile 2>/dev/null) || tempfile=/tmp/test$$

SRV_PATH="${HOME}"/server/serverfiles
STEAM_DIR="${HOME}"/mods/steam

# Get MODs list from Steam directory
for M_DIR in $(ls -1 ${STEAM_DIR} | grep -vE "*_old_*"); do
    # Get MOD name and ID
    if [[ -f "${STEAM_DIR}"/"${M_DIR}"/meta.cpp ]]; then
	MOD_NAME=$(grep -h "name" "${STEAM_DIR}"/"${M_DIR}"/meta.cpp | \
	awk -F'"' '{print $2}' | \
	tr -d "[:punct:]" | \
	tr "[:upper:]" "[:lower:]" | \
	sed -E 's/\s{1,}/_/g' | \
	sed 's/^/\@/g')
	MOD_ID=$(grep -h "publishedid" "${STEAM_DIR}"/"${M_DIR}"/meta.cpp | awk '{print $3}' | tr -d [:punct:])
    fi
    # Check if MDO already linked to the game directory and write it to list
    if [[ -d "${SRV_PATH}"/${MOD_NAME} ]] || [[ -h "${SRV_PATH}"/${MOD_NAME} ]]; then
	echo -e "${MOD_NAME} ${MOD_ID} ON" >>${INSTALLED_LIST}
    else
	echo -e "${MOD_NAME} ${MOD_ID} off" >>${INSTALLED_LIST}
    fi
done

# Construct pseudograpchicel interface
$DIALOG --backtitle "Select MOD to connect" \
	--keep-tite \
        --title "MOD selection" --clear \
        --checklist "Selected MODs... " 70 70 25 \
	$(cat ${INSTALLED_LIST}) 2>$tempfile

retval=$?

# Find a switched off MODs
choice_id_list="$(for name in $(cat ${tempfile}); do grep -v ON ${INSTALLED_LIST} | grep ${name} ${INSTALLED_LIST} | awk '{ print $2 }'; done)"

case $retval in
  0)
    for mod_id in ${choice_id_list[@]}; do
	for name in $(grep ${mod_id%$'\r'} $INSTALLED_LIST | awk '{ print $1 }'); do
	    if [[ -d "${SRV_PATH}"/${name%$'\r'} ]] || [[ -h "${SRV_PATH}"/${name%$'\r'} ]]; then
		continue
	    else
		# Link MOD's Steam path to Server directory by its name
		ln -s ${STEAM_DIR}/${mod_id%$'\r'} "${SRV_PATH}"/${name%$'\r'} 2>/dev/null
		# Check for a "key/keys" directory in a linked MOD's directory and create symbolic links for all keys in it to a server's "keys" directory
		if [[ -d "${SRV_PATH}"/${name%$'\r'}/keys ]]; then
		    ln -s "${SRV_PATH}"/${name%$'\r'}/keys/* "${SRV_PATH}"/keys/ 2>/dev/null
		elif [[ -d "${SRV_PATH}"/${name%$'\r'}/key ]]; then
		    ln -s "${SRV_PATH}"/${name%$'\r'}/key/* "${SRV_PATH}"/keys/ 2>/dev/null
		else
		    continue
		fi
	    fi
	done
    done
    ;;
  1)
    echo "Canceled."
    ;;
  255)
    echo "ESC key pressed."
    ;;
esac

exit 0