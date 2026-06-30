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

set -x

    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_HOME"
#    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_HOME/src"
    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST"

    info "Installing repository files"

    # First pass: simple copy. We can refine this later with rsync, mtree, or explicit install rules.
    tar -C "$VIDAR_SRC" \
        --exclude .git \
        --exclude .gitignore \
        --exclude .gitkeep \
        --exclude vidar_install.sh \
        --exclude deprecated \
        -cf - . | tar -C "$VIDAR_DST" -xf -

    chown -R "$VIDAR_USER:$VIDAR_GROUP" "$VIDAR_DST"
set +x
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

    [ -f "$VIDAR_DST/vidar_install.sh" ] && chmod 0755 "$VIDAR_DST/vidar_install.sh"
}

fix_runtime_symlinks() {
    info "Setting runtime symlinks"

    # Default to dev unless explicitly changed later.
    if [ -f "$VIDAR_DST/etc/vidar_dev.sh" ]; then
        ln -sfn vidar_dev.sh "$VIDAR_DST/etc/vidar_env.sh"
        chown -h root:"$VIDAR_GROUP" "$VIDAR_DST/etc/vidar_env.sh"
    fi
}

create_runtime_dirs() {
    info "Creating runtime directories"

    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST/logs"
    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST/run"
}


show_all_vars() {
    echo
    echo "VIDAR_DB    =[${VIDAR_DB}]"
    echo "VIDAR_DST   =[${VIDAR_DST}]"
    echo "VIDAR_ETC   =[${VIDAR_ETC}]"
    echo "VIDAR_GROUP =[${VIDAR_GROUP}]"
    echo "VIDAR_HOME  =[${VIDAR_HOME}]"
    echo "VIDAR_MODE  =[${VIDAR_MODE}]"
    echo "VIDAR_SRC   =[${VIDAR_SRC}]"
    echo "VIDAR_USER  =[${VIDAR_USER}]"
    echo "WHEREAMI    =[${WHEREAMI}]"
    echo
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
            ;;
        [Pp][Rr][Oo][Dd])
            VIDAR_MODE=prod
            ;;
        *)
            usage
            ;;
    esac

    # We presume we are at the top of the Vidar source tree after
    # a git clone or fetch.  But this might not actually be the
    # case, so we have to find out if we actually are at the top
    # of the Vidar source tree.

    # Set some initial variables.
    WHEREAMI=$(pwd)
    echo $WHEREAMI

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
      echo "Directory [${WHEREAMI}] does not seem to be a correct Vidar src?"
      echo "Check directory contents or perform a git pull in this directory"
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
exit
    fix_permissions
    fix_runtime_symlinks
    create_runtime_dirs

    info "Vidar base install complete"
    info "Next steps: database setup, sudoers setup, rc/service setup"
}

main "$@"
