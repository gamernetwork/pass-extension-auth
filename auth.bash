#!/usr/bin/env bash

set -o errexit
set -o pipefail

no_colour="\033[0m"
black="\[\033[0;30m"
red="\033[0;31m"
green="\033[0;32m"
yellow="\033[0;33m"
blue="\033[0;34m"
purple="\033[0;35m"
cyan="\033[0;36m"
white="\033[0;37m"
bold=$(tput bold)
normal=$(tput sgr0)

usage() {
    cat << END_USAGE

Display users that can view and edit an entry:

    pass auth path/to/key

To add or remove users from an entry:

    pass auth path/to/key [add|rm] <gpg_id>

END_USAGE
}

gpg_key_exists() {
    if [ "$#" -eq 1 ]; then
       gpg --list-key $1 > /dev/null 2>&1
    else
        echo "Usage: ${FUNCNAME[0]} <gpg_key_id>"
    fi
}


get_gpg_id_file() {
    local current="$1/$2"
    while [[ $current != "$PREFIX" && ! -f $current/.gpg-id ]]; do
        current="${current%/*}"
    done
    echo "$current/.gpg-id"
}


get_gpg_recipients() {
    local id_path=$1
    GPG_RECIPIENT_ARGS=( )
    GPG_RECIPIENTS=( )

    if [[ -n $PASSWORD_STORE_KEY ]]; then
        for gpg_id in $PASSWORD_STORE_KEY; do
            GPG_RECIPIENT_ARGS+=( "-r" "$gpg_id" )
            GPG_RECIPIENTS+=( "$gpg_id" )
        done
        return
    fi

    gpg_id_file=$(get_gpg_id_file $PREFIX $id_path)

    verify_file "$gpg_id_file"

    if [[ $id_path == "NONE" ]]; then
        printf "\nUsers with full access to the password store:\n\n"
    else
        printf "\nUsers with access to $entry_type ${bold}${id_path}${normal}:\n\n"
    fi
    printf "$green"
    cat "$gpg_id_file" | sort | sed 's/^/\t/'
    printf "$no_colour\n"
}


lineinfile() {

    local changed=1
    if [ $# -ge 2 ]; then
        local file=$1
        local line=$2
        local state=${3:-"present"}
    else
        echo "Failed in function ${FUNCNAME[0]}"
        echo "Usage: ${FUNCNAME[0]} file line [state]"
        exit 1
    fi
    if grep -q $line $file; then
        if [ $state = "absent" ]; then
            sed  -i "/$line/d" $file
            changed=0
        fi
    else
        if [ $state = "present" ]; then
            echo $line >> $gpg_id_file
            changed=0
        fi
    fi
    return $changed
}


update_gpg_recipient() {

    if [ $# -eq 2 ]; then
        local user=$1
        local state=$2
    else
        echo "Failed in function ${FUNCNAME[0]}"
        echo "Usage: ${FUNCNAME[0]} user state"
        exit 1
    fi

    local changed=1
    local inherited=1
    local gpg_id_file="$PREFIX/$id_path/.gpg-id"
    local parent_gpg_id_file=$(get_gpg_id_file "$PREFIX" "$id_path")

    # Always inherit parent folder gpg-ids if no .gpg-id is present
    if [ "$parent_gpg_id_file" != "$gpg_id_file" ]; then
        echo "Copy $parent_gpg_id_file to $gpg_id_file"
        cp $parent_gpg_id_file $gpg_id_file
        inherited=0
    fi

    if [ $state = "present" ]; then
        printf "\nAdding user ${bold}${user}${normal} to $entry_type ${bold}${id_path}${normal}\n\n"
    elif [ $state = "absent" ]; then
        printf "\nRemoving user ${bold}${user}${normal} from $entry_type ${bold}${id_path}${normal}\n\n"
    fi

    if lineinfile $gpg_id_file $user $state; then
        changed=0
    elif [ $inherited -eq "0" ]; then
        changed=0
    fi

    return $changed
}


git_add_file() {
    git -C "$PREFIX" add "$1"
    git -C "$PREFIX" commit -m "$2"
}


set_id_path() {
    entry_type="directory"
    id_path=$1
    if [[ ! -d "$PREFIX/$id_path" ]] && [[ ! -f "$PREFIX/$id_path.gpg" ]]; then
        printf "\nNo entry in pass for ${bold}${id_path}${normal}\n\n"
        exit 1
    elif [[ -d "$PREFIX/$id_path" ]] && [[ -f "$PREFIX/$id_path.gpg" ]]; then
        printf "\nPass has both a key and directory entry for ${bold}${id_path}${normal}\n\nChoose which type to use\n\n"
        select entry_type in "key" "directory"; do
            case $entry_type in
                key)
                    id_path=$(dirname $id_path)
                    break
                    ;;
                directory)
                    break
                    ;;
                *) echo "Select key or directory"
            esac
        done
    fi
}


if [ $# -le 1 ]; then
    set_id_path $1
    get_gpg_recipients $id_path
elif [ $# -eq 3 ]; then
    user=$3
    if ! gpg_key_exists $user; then
        printf "\nError: no gpg key exists for user $user\n\n"
        exit 1
    fi
    case $2 in
        add)
            set_id_path $1
            if update_gpg_recipient $user "present"; then
                reencrypt_path "$PREFIX/$id_path"
                git_add_file "$PREFIX/$id_path" "Added user ${user} to ${id_path}"
            fi
            ;;
        delete|rm)
            set_id_path $1
            if update_gpg_recipient $user "absent"; then
                reencrypt_path "$PREFIX/$id_path"
                git_add_file "$PREFIX/$id_path" "Removed user ${user} from ${id_path}"
            fi
            ;;
        *)
            usage
            ;;
    esac
fi
