#!/bin/bash

set -e

SCRIPT_LOCT=`dirname $0`
SCRIPT_LOCT=`cd $SCRIPT_LOCT; pwd`
cd $SCRIPT_LOCT


if [ -z "$1" ]; then
	>&2 echo "Error: first parameter should be either gham or bot"
	exit 1
fi

YAML_FILE="$1.yml"

# if [ "$1" == "gham" ]; then
# 	YAML_FILE=gham.yml
# else
# 	YAML_FILE=codewind-bot.yml
# fi


if [ -z "$2" ]; then
	echo "Error: Path to inventory file is not specified"
	exit 1
fi
PATH_TO_INVENTORY_FILE=$2

if [ -z "$3" ]; then
	echo "Error: Path to Configuration YAML is not specified."
	exit 1
fi

set -euo pipefail

if [ "$1" == "codewind-bot" ]; then
	export BOT_CONF_YAML_PATH=$3
	echo "* Using Bot YAML Config path: $BOT_CONF_YAML_PATH"

	# Bot deployment requires authorized users list
	if [ -z "$4" ]; then
		>&2 echo "Error: Path to authorized bot users is not specified."
		exit 1
	else
		export BOT_PATH_TO_AUTHORIZED_USERS=$4
	fi

else
	export GHAM_CONF_YAML_PATH=$3
	echo "* Using GHAM YAML Config path: $GHAM_CONF_YAML_PATH"
fi




ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_STDOUT_CALLBACK=debug ansible-playbook -v -i "$PATH_TO_INVENTORY_FILE" "./$YAML_FILE"



