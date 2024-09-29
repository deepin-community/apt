#!/bin/bash
set -e

immutable_mode=0

immutable_bin=""
real_flag=0
support_option_flag=0
orignal_args=("$@")

readonly cmd_src=apt
readonly orig_bin=apt.real

readonly conf_file="/usr/share/apt/apt-immutable.cfg"
readonly override_conf="/etc/apt/apt-immutable.cfg"

function parse_args {
    while [ "$#" -gt 0 ]; do
        arg="$1"
        shift
        case $arg in
        install|reinstall|remove|purge|build-dep)
            immutable_mode=1;
            ;;
        --real)
            real_flag=1
            ;;
        --download-only|--dry-run|-d|--simulate|--just-print|--recon|--no-act|-s|-h|--help)
            support_option_flag=1
            ;;
        esac
    done
}

# Parse configuration file
function parse_value_from_config {
    local file=$1
    while IFS='=' read -r key value; do
        if [[ $key == \#* ]]; then
            continue
        fi

        key="${key## }"
        key="${key%% }"
        case $key in
            immutable_bin)
                if [ -z "${immutable_bin}" ]; then
                    immutable_bin="$value"
                fi
                ;;
            *)
                ;;
        esac
    done < "$file"
}

# Read configuration files,override_conf has higher priority than conf_file
function read_config {
    if [ -f "${override_conf}" ]; then
        parse_value_from_config "${override_conf}"
    fi
    if [ -f "${conf_file}" ]; then
        parse_value_from_config "${conf_file}"
    fi
}

# Function to check if immutable system
function is_immutable_os {
    local status_output

    if ! command -v deepin-immutable-ctl &> /dev/null; then
        return 1
    fi

    # Call deepin-immutable-ctl status and get the output. The output is
    # true, indicating an immutable system.
    status_output=$(deepin-immutable-ctl --immutable-status)
    if echo "$status_output" | grep -q "immutable-mode:true"; then
        return 0
    else
        return 1
    fi
}

# Since the configured program has parameters, the program name must be parsed
# and extracted before it can be called
function exec_program {
    local binname args COMMAND PARAMETERS
    binname=$1
    shift
    args=("$@")

    IFS=' ' read -ra CMD_ARGS <<< "$binname"
    COMMAND="${CMD_ARGS[0]}"
    PARAMETERS=("${CMD_ARGS[@]:1}")
    PARAMETERS+=("${args[@]}")
    "${COMMAND}" "${PARAMETERS[@]}"
}

function exec_orignal_bin_with_real_flag {
    local newarg=()
    for arg in "${orignal_args[@]}"; do
        if [[ "$arg" != "--real" ]]; then
            newarg+=("$arg")
        fi
    done
    "${orig_bin}" "${newarg[@]}"
}

function exec_orignal_bin {
    "${orig_bin}" "${orignal_args[@]}"
}

function exec_immutable_ctl {
    read_config
    if [ -z "${immutable_bin}" ]; then
        echo "not config immutable_bin in ${conf_file} or ${override_conf}"
        return 1
    fi
    exec_program "${immutable_bin} ${cmd_src}" "${orignal_args[@]}"
}

function main {
    parse_args "$@"
    if [ $real_flag -eq 1 ]; then
        exec_orignal_bin_with_real_flag
        exit $?
    fi
    if [ $support_option_flag -eq 1 ]; then
        exec_orignal_bin
        exit $?
    fi
    if [ $immutable_mode -eq 1 ] && is_immutable_os; then
        exec_immutable_ctl
        exit $?
    fi
    exec_orignal_bin
}

main "$@"
