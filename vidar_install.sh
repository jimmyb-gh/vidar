#!/bin/sh

# vidar_install.sh - Installation file for Vidar.

#set -eu

#set -x

# Function definitions.  See main() below for startup.

usage() {
    echo "usage: $0 dev|prod" >&2
    exit 1
}

greetings() {
    echo
    echo "Welcome to the Vidar installation script."
    echo
}

warn() {
    echo "WARN: $*" >&2
    echo
}

die() {
    echo "ERROR: $*" >&2
    echo
    exit 1
}

info() {
    echo "==> $*"
}

need_root() {
    # Must be root.
    [ "$(id -u)" -eq 0 ] || die "Run this installer as root."
}

check_platform() {
    [ "$(uname -s)" = "FreeBSD" ] || die "This installer currently supports FreeBSD only."
}

check_required_commands() {
    for cmd in install chown chmod pw psql service sudo; do
        command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
    done
}

ensure_vidar_user_and_group() {
    if ! pw groupshow "$VIDAR_GROUP" >/dev/null 2>&1; then
        info "Creating group $VIDAR_GROUP"
        pw groupadd "$VIDAR_GROUP"
    else
        info "Vidar group name [${VIDAR_GROUP}] already exists."
    fi

    if ! id "$VIDAR_USER" >/dev/null 2>&1; then
        info "Creating user $VIDAR_USER"
        pw useradd "$VIDAR_USER" \
            -g "$VIDAR_GROUP" \
            -m \
            -c "Vidar Odinson" \
            -d "$VIDAR_HOME" \
            -s /bin/sh
    else
        info "Vidar password entry [${VIDAR_USER}] already exists."
    fi
}

install_tree() {
    info "Creating destination tree"

    # VIDAR_DST is the intended location of the installed runtime code.
    # The intended layout is:
    #  $VIDAR_DST
    #      |- etc/         - Vidar configuration files vidar_env.sh, vidar_dev.sh, and vidar_prod.sh
    #      |- input/       - Vidar test input location
    #      |- libexec/     - Vidar special scripts
    #      |- logs/        - Vidar runtime logs
    #      |- pids/        - Vidar runtime process ids
    #      |- postgres/    - Vidar scripts that interact with PostgreSQL
    #      |- scripts/     - Vidar runtime scripts
    #      |- sec/         - SEC rules files and setup files
    #      |- testdata/    - Vidar files to use for testing
    #      |- utils/       - Vidar utilities to perform testing

    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_HOME"
#    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_HOME/src"
    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST"

    info "Installing repository files"

    # First pass: simple copy. We can refine this later with rsync, mtree, or explicit install rules.
    tar -C "$VIDAR_SRC" \
        --exclude .git \
        --exclude .gitignore \
        --exclude .gitkeep \
        --exclude deprecated \
        --exclude vidar_install.sh \
        -cf - . | tar -C "$VIDAR_DST" -xf -

    chown -R "$VIDAR_USER:$VIDAR_GROUP" "$VIDAR_DST"


}

fix_permissions() {
    info "Fixing permissions"

    find "$VIDAR_DST" -type d -exec chmod 0755 {} +
    find "$VIDAR_DST" -type f -exec chmod 0644 {} +

    # Executable scripts
    find "$VIDAR_DST/scripts" "$VIDAR_DST/postgres" \
        -type f \
        \( -name "*.sh" -o -name "*.pl" \) \
        -exec chmod 0755 {} + 2>/dev/null || true

# excluded     [ -f "$VIDAR_DST/vidar_install.sh" ] && chmod 0755 "$VIDAR_DST/vidar_install.sh"
}

fix_runtime_environment() {
    info "Setting runtime environment in ${VIDAR_ETC}/vidar_env.sh"
    # Default to dev unless explicitly changed later.
    ( cd ${VIDAR_ETC}
        # Set up the VIDAR_HOME and VIDAR_ENVIRONMENT variables.
        # These have to be done inline so the variable values will transfer.
        cat vidar_env.sh.setup | \
            sed -e "s]@@@VIDAR_HOMEDIR@@@]${VIDAR_DST}]" \
                -e "s]@@@VIDAR_ENVIRONMENT_TAG@@@]${VIDAR_ENVIRONMENT}]" \
                 > vidar_env.sh

      chown -h root:"$VIDAR_GROUP" "$VIDAR_ETC/vidar_env.sh"
    )
}

create_runtime_dirs() {
    info "Creating runtime directories"

    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST/logs"
    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST/pids"
}


show_all_vars() {

    echo "The following environment variables will be used:"
    echo
    echo "VIDAR_DB    =[${VIDAR_DB}]"
    echo "VIDAR_DST   =[${VIDAR_DST}]"
    echo "VIDAR_ETC   =[${VIDAR_ETC}]"
    echo "VIDAR_GROUP =[${VIDAR_GROUP}]"
    echo "VIDAR_HOME  =[${VIDAR_HOME}]"
    echo "VIDAR_MODE  =[${VIDAR_MODE}]"
    echo "VIDAR_SRC   =[${VIDAR_SRC}]"
    echo "VIDAR_USER  =[${VIDAR_USER}]"
    echo
}


vidar_sudoers_setup() {
    info "Setting up vidar in /usr/local/etc/sudoers.d/vidar"

    VIDAR_SUDOERSD=/usr/local/etc/sudoers.d        # The directory
    VIDAR_SUDOERSD_FILE="${VIDAR_SUDOERSD}/vidar"  # The file
    VISUDO="/usr/local/sbin/visudo"                # The validator 

    [ -x "$VISUDO" ] || die "visudo not found or not executable at [${VISUDO}]"
    [ -n "${VIDAR_DST:-}" ] || die "VIDAR_DST is not set in vidar_sudoers_setup()."

    install -d -o root -g wheel -m 0750 "$VIDAR_SUDOERSD"

    # ChatGPT recommends checking the sudoers.d/vidar file with visudo
    # so we do that first:

    tmpfile="$(mktemp ./vidar_sudoers.XXXXXX)" || die "mktemp file in vidar_sudoers_setup()."

    cat > "$tmpfile" <<EOF
vidar ALL=(root) NOPASSWD: ${VIDAR_DST}/libexec/vidar_ipfw_delete.sh
EOF

    chown root:wheel "$tmpfile"
    chmod 0440 "$tmpfile"
    "$VISUDO" -c -f "$tmpfile" || {
        rm -f "$tmpfile"
        die "sudoers validation failed in vidar_sudoers_setup()."
    }
    
    # Just replace any existing sudoers.d/vidar file
    if [ -f "${VIDAR_SUDOERSD}/vidar" ]
    then
        # Move it out of the way.
        mv "${VIDAR_SUDOERSD}/vidar" "${VIDAR_SUDOERSD}/vidar.OLD"
    fi

    # Install what we need for dev or prod
    install -o root -g wheel -m 0440 "$tmpfile" "$VIDAR_SUDOERSD_FILE"
    rm -f "$tmpfile"

    # And set permissions on the helper file.
     chown root:wheel "$VIDAR_DST/libexec/vidar_ipfw_delete.sh"
     chmod 0550  "$VIDAR_DST/libexec/vidar_ipfw_delete.sh"
}


# Ok, light 'er up!
main() {

    greetings

    need_root

    check_platform


    # Check args inline.
    # Must have either 'dev' or 'prod' as a single argument.
    [ $# -eq 1 ] || usage

    VIDAR_MODE="$1"

    case "$VIDAR_MODE" in
        [Dd][Ee][Vv])
            VIDAR_MODE=dev  # Set to lower case.
            VIDAR_ENVIRONMENT=DEVELOPMENT
            ;;
        [Pp][Rr][Oo][Dd])
            VIDAR_MODE=prod
            VIDAR_ENVIRONMENT=PRODUCTION
            ;;
        *)
            warn "Incorrect parameter [${VIDAR_MODE}]"
            usage
            ;;
    esac

    # We presume we are at the top of the Vidar source tree after
    # a git clone or fetch.  But this might not actually be the
    # case, so we have to find out if we actually are at the top
    # of the Vidar source tree.

    # Set some initial variables.
    WHEREAMI=$(pwd)
    echo "Current directory is ${WHEREAMI}."

    # VIDAR_SRC is the top level of the Vidar source tree, typically /home/vidar/src/vidar
    if [ -d ${WHEREAMI}/etc -a -d ${WHEREAMI}/input \
         -a -d ${WHEREAMI}/libexec -a -d ${WHEREAMI}/postgres \
         -a -d ${WHEREAMI}/scripts -a -d ${WHEREAMI}/sec \
         -a -d ${WHEREAMI}/testdata -a -d ${WHEREAMI}/utils \
         -a -d ${WHEREAMI}/.git ]
    then
    # Good chance we are in the source directory for Vidar.
      VIDAR_SRC=$(pwd)
      echo "Assuming VIDAR_SRC as ${VIDAR_SRC}"
    else
      echo
      warn "Directory [${WHEREAMI}] does not seem to be a complete and correct Vidar source dir."
      die "Check directory contents or perform a git clone in this directory."
       
    fi

    # Need VIDAR_HOME to be the home directory of user vidar.
    VIDAR_HOME=/home/vidar

    # VIDAR_DST is the destination for a successful install.
    # The install depends on the VIDAR_MODE parameter passed.
    # The development default is VIDAR_HOME/dev.
    # The production default is /usr/local/vidar.

    if [ "X${VIDAR_MODE}" = "Xdev" ]
    then
        VIDAR_DST=${VIDAR_HOME}/dev   # Development
    else
        VIDAR_DST=/usr/local/vidar    # Production
    fi
    
    VIDAR_ETC="${VIDAR_DST}/etc"

    VIDAR_USER="vidar"
    VIDAR_GROUP="vidar"
    VIDAR_DB="vidar"

    check_required_commands

    show_all_vars

    ensure_vidar_user_and_group

    install_tree

    fix_permissions

    fix_runtime_environment

    create_runtime_dirs

    vidar_sudoers_setup

    info "Vidar base install complete"

    info "Next steps: database setup, rc/service setup"
}

main "$@"
