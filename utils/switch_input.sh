#!/bin/sh
#
#  switch_input.sh - this script changes the input log variables
#                    AUTHLOG, EMAILLOG, and NGINXLOG
#                    to production locations or to test locations.
#
#  Variable     Test Locations             Production Locations
#  -------------------------------------------------------------
#  AUTHLOG      ${VIDAR_INPUT}/auth.log    /var/log/auth.log 
#  EMAILLOG     ${VIDAR_INPUT}/maillog     /var/log/maillog
#  NGINXLOG     ${VIDAR_INPUT}/access.log  /var/log/nginx/access.log 
#
#
# These variables are in ${VIDAR_ETC}/vidar_env.sh 
#
# The order of operations is to:
#  - stop Vidar with ${VIDAR_SCRIPTS/vidar_stop.sh
#  - switch variables with this script $VIDAR_UTILS/switch_input.sh test|prod
#  - restart Vidar with $VIDAR_SCRIPTS/vidar_start_postgres.sh 
#
# SEC will read input from the assigned locations.
#
# Must be root to run this script.
#
# Must already have sourced ${VIDAR_ETC}/vidar_env.sh to run this script.
#


usage() {
    echo "usage: $0 test|prod" >&2
    exit 1
}

greetings() {
    echo
    info "NOTE: you are running switch_input.sh with [${MODE}]"
}



warn() {
    echo "==> WARN: $*" >&2
    echo
}

die() {
    echo "==> ERROR: $*" >&2
    echo
    exit 1
}

info() {
    echo "==> $*"
}

need_root() {
    # Must be root.
    [ "$(id -u)" -eq 0 ] || die "Must run switch_input.sh as root."
}

# Check the environment to ensure all Vidar variables are available
check_environment() {
    if [ -z "${VIDAR_HOME}" -o \
         -z "${VIDAR_SCRIPTS}" -o \
         -z "${VIDAR_SEC}" -o \
         -z "${VIDAR_UTILS}" -o \
         -z "${VIDAR_PIDS}" -o \
         -z "${VIDAR_INPUT}" -o \
         -z "${VIDAR_ETC}" -o \
         -z "${VIDAR_LIBEXEC}" -o \
         -z "${AUTHLOG}" -o \
         -z "${EMAILLOG}" -o \
         -z "${NGINXLOG}" ]
    then
        warn "Vidar environment is not set or is corrupted."
        die "Source Vidar environment from vidar_env.sh and try again."
        exit 1
    fi
}


switch_input_mode() {
    if [ -z "${MODE}" ] 
    then
       die "No input mode parameter provided."
    fi

    ENVFILE="${VIDAR_ETC}/vidar_env.sh"

    if [ ! -f "${ENVFILE}" ] 
    then
       die "Vidar environment not sourced. Source environment first."
    fi


    case "${MODE}" in
        [Tt][Ee][Ss][Tt])
            VIDAR_INPUT_MODE=test  # Set to lower case.
            authlog='${VIDAR_INPUT}/auth.log'
            emaillog='${VIDAR_INPUT}/maillog'
            nginxlog='${VIDAR_INPUT}/access.log'
            ;;
        [Pp][Rr][Oo][Dd])
            VIDAR_INPUT_MODE=prod
            authlog='/var/log/auth.log'
            emaillog='/var/log/maillog'
            nginxlog='/var/log/nginx/access.log'
            ;;
        *)
            warn "Incorrect parameter [${MODE}]"
            usage
            ;;
    esac

    tmpfile="$(mktemp ./vidar_env.XXXXXX)" || die "mktemp failed."

    # Use awk to do the changes.
    awk \
        -v authlog="$authlog" \
        -v emaillog="$emaillog" \
        -v nginxlog="$nginxlog" \
      '
        BEGIN {
            found_auth  = 0
            found_email = 0
            found_nginx = 0
        }

        /^export[[:space:]]+AUTHLOG=/ {
            print "export AUTHLOG=" authlog
            found_auth = 1
            next
        }

        /^export[[:space:]]+EMAILLOG=/ {
            print "export EMAILLOG=" emaillog
            found_email = 1
            next
        }

        /^export[[:space:]]+NGINXLOG=/ {
            print "export NGINXLOG=" nginxlog
            found_nginx = 1
            next
        }

        {
            print
        }

        END {
            if (!found_auth) {
                print "ERROR: AUTHLOG export variable not found" > "/dev/stderr"
                exit 1
            }
            if (!found_email) {
                print "ERROR: EMAILLOG export variable not found" > "/dev/stderr"
                exit 1
            }
            if (!found_nginx) {
                print "ERROR: NGINXLOG export variable not found" > "/dev/stderr"
                exit 1
            }
        }
    ' "${ENVFILE}" > "${tmpfile}" || {
        rm -f "${tmpfile}"
        die "Failed to rewrite ${ENVFILE}"
    }

    cp -p "${ENVFILE}" "${ENVFILE}.OLD" || {
        rm -f "${tmpfile}"
        die "Failed to create backup file ${ENVFILE}.OLD"
    }

    cat "$tmpfile" > "${ENVFILE}" || {
        rm -f "${tmpfile}"
        die "Failed to update ${ENVFILE}"
    }

    rm -f "${tmpfile}"

    info "SUCCESS: Switched $(basename "${ENVFILE}") input mode to ${MODE}"
    info "Restart Vidar to take effect."
}


# Ok, light 'er up!
main() {


    if [ $# -ne 1 ]
    then
       usage;
    else
       MODE=$1
    fi

    echo "Requested mode is [${MODE}]"

    greetings

    need_root    

    check_environment

    switch_input_mode ${MODE}
}

main "$@"
