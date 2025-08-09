#!/bin/sh

if [ "$#" -lt 1 ]; then
    echo "Usage: ${0} <level_number>"
    exit 1
fi

lines_in_file=$(wc -l narnia_pass | awk '{print $1}')

if [ "$1" = "add" ]; then
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${0} add <level_password>"
        exit 2
    fi

    echo "sshpass -p ${2} ssh narnia${lines_in_file}@narnia.labs.overthewire.org -p 2226" >>narnia_pass
else
    narnia_level=$(($1 + 1))
    if [ $narnia_level -gt $lines_in_file ]; then
        echo "You don't have the password for narnia${1} yet!"
        exit 3
    fi
    $(sed -n "${narnia_level}p" narnia_pass)
fi
