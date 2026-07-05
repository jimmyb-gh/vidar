#!/bin/sh

# vidar_database_init.sh - Installation file for Vidar database.
#
################################################################
#                                                              #
#      WARNING - this script completely removes all data       #
#                and roles from the Vidar database.            #
#                                                              #
#           BACKUP YOUR DATABASE IF THIS IS A CONCERN.         #
#                                                              #
################################################################

#set -eu

#set -x

# Function definitions.  See main() below for startup.

usage() {
    echo "usage: $0 dev|prod" >&2
    exit 1
}

greetings() {
    echo
    info "Welcome to the Vidar database initialization script."
    info ""
    info "################################################################"
    info "#                                                              #"
    info "#      WARNING - this script completely removes all data       #"
    info "#                and roles from the Vidar database.            #"
    info "#                                                              #"
    info "#           BACKUP YOUR DATABASE IF THIS IS A CONCERN.         #"
    info "#                                                              #"
    info "################################################################"
    info ""
    info "Do you wish to proceed \"Yes\" or \"No\"?"
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

read_yesno() {
    while(:) 
        do
            read -p "==> Do you wish to proceed \"Yes\" or \"No\"?: " PROMPT_ANSWER
            #echo "Read value [${PROMPT_ANSWER}]" 
            case "${PROMPT_ANSWER}" in
                [Yy][Ee][Ss])
                    #echo "YES CASE"
                    DB_ANSWER="yes"
                    break;
                    ;;
                [Nn][Oo])
                    #echo "NO CASE"
                    DB_ANSWER="no"
                    break;
                    ;;
                *)
                    #echo "BAD INPUT CASE"
                    echo "Please answer Yes or No"
                    continue;
                ;;
            esac
      done
      #echo "AFTER CASE and WHILE, PROMPT_ANSWER is [${PROMPT_ANSWER}]"
      #echo "AFTER CASE and WHILE, DB_ANSWER is [${DB_ANSWER}]"
}

info() {
    echo "==> INFO: $*"
}

need_root() {
    # Must be root.
    [ "$(id -u)" -eq 0 ] || die "Run this installer as root."
}

check_platform() {
    [ "$(uname -s)" = "FreeBSD" ] || die "This installer currently supports FreeBSD only."
}

check_required_commands() {
    for cmd in install chown chmod pw psql service sudo visudo; do
        command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
    done
}

#  Vidar userid and group already exist.
#  Created and installed by vidar_install.sh
#  No need to do it again here.
#
#ensure_vidar_user_and_group() {
#    if ! pw groupshow "$VIDAR_GROUP" >/dev/null 2>&1; then
#        info "Creating group $VIDAR_GROUP"
#        pw groupadd "$VIDAR_GROUP"
#    else
#        info "Vidar group name [${VIDAR_GROUP}] already exists."
#    fi
#
#    if ! id "$VIDAR_USER" >/dev/null 2>&1; then
#        info "Creating user $VIDAR_USER"
#        pw useradd "$VIDAR_USER" \
#            -g "$VIDAR_GROUP" \
#            -m \
#            -c "Vidar Odinson" \
#            -d "$VIDAR_HOME" \
#            -s /bin/sh
#    else
#        info "Vidar password entry [${VIDAR_USER}] already exists."
#    fi
#}
#

vidar_database_init() {

    if ! [ -z "${VIDAR_POSTGRES}" ]
    then
        echo "psql -U postgres -d postgres -f ${VIDAR_POSTGRES}/vidar.sql"
        psql -U postgres -d postgres -f ${VIDAR_POSTGRES}/vidar.sql
    else
        die "VIDAR_POSTGRES not found!  Aborting..."
    fi
}

check_environment() {
    # We presume we are at the top of the Vidar destination tree after
    # a successful install.  But this might not actually be the
    # case, so we have to find out if we actually are at the top
    # of the Vidar destination tree.
    # Note that this is similar but different from the vidar_install.sh
    # code.  Here we need to determine where we are successfully installed.
    # 
    # We have a definite clue in the file /usr/local/etc/sudoers.d/vidar.
    # The execution field in that file is the result of the last installation.
    # We can determine the location of the top of the installation tree
    # by examining that field.



    TOP_OF_TREE=$(
    awk '
        BEGIN {
            found = 0
        }
        # Skip blank lines and comments
        /^[[:space:]]*$/ { next }
        /^[[:space:]]*#/ { next }

        {
            for (i - 1; i <= NF; i++) {
                if ($i ~ /vidar_ipfw_delete\.sh$/) {
                    helper = $i
                    gsub(/,$/, "", helper)
                    found  = 1
 
                    # Production install found:
                    #
                    # /usr/local/libexec/vidadr/vidar_ipfw_delete.sh
                    # maps to:
                    # /usr/local/vidar
                    #
                    if (helper == "/usr/local/libexec/vidar/vidar_ipfw_delete.sh") {
                        print "/usr/local/vidar"
                        exit 0
                    }

                    # Development type install found.  NOT THE SAME AS ABOVE!
                    # 
                    # /some/top/of/tree/libexec/vidar/vidar_ipfw_delete.sh
                    # maps to:
                    # /some/top/of/tree
                    #

                    if (helper ~ /\/libexec\/vidar_ipfw_delete\.sh$/) {
                        sub(/\/libexec\/vidar_ipfw_delete\.sh$/, "", helper)
                        print helper
                        exit 0
                    }

                    print "ERROR: unrecognized vidar helper path: " helper > "/dev/stderr"
                    exit 1
                }
            }
        }
        END  {
            if (!found) {
                print "ERROR: no vidar_ipfw_delete.sh entry found" > "/dev/stderr"
                exit 1
           }
        }
    ' /usr/local/etc/sudoers.d/vidar ) || exit 1  # read from sudoers.d/vidar file


    # We now have the top of the Vidar installed tree
      VIDAR_DST="${TOP_OF_TREE}"
      echo "Assuming VIDAR_DST as ${VIDAR_DST}"

    # Test VIDAR_DST and see if the etc directory and the
    # vidar_env.sh file exists.  If so, source the vidar_env.sh file.

    VIDAR_ETC="${VIDAR_DST}/etc"

    # Source the file.

    SHOW_ENV="Y"
    . "${VIDAR_ETC}/vidar_env.sh"

    # Extra variables we need. 
    VIDAR_USER="vidar"
    VIDAR_DB="vidar"
}


# Ok, light 'er up!
main() {

    need_root

    check_platform

    check_required_commands


    greetings

    read_yesno

    check_environment

    # ensure_vidar_user_and_group

    vidar_database_init

    info "Vidar database initialization complete"

    info "Next steps: rc/service setup"
}

main "$@"
