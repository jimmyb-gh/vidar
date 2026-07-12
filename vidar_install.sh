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
    echo "==> WARN: $*" >&2
    echo
}

die() {
    echo "==> ERROR: $*" >&2
    echo
    exit 1
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
    #      |- etc/         - Vidar configuration file vidar_env.sh
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
    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST"

    info "Installing repository files"

    # Copy steps: Copy, set default ownership, set root:wheel exceptions, set execute permissions
    # tar option -p maintains the execute bits when extracting the archive.
    tar -C "$VIDAR_SRC" \
        --exclude .git \
        --exclude .gitignore \
        --exclude deprecated \
        --exclude vidar_install.sh \
        -cf - . | tar -C "$VIDAR_DST" -xpf -

#        --exclude .gitkeep \

    # Set default ownership for all.
    chown -R "$VIDAR_USER:$VIDAR_GROUP" "$VIDAR_DST"

    # Apply root:wheel  exceptions
    chown root:wheel \
        "${VIDAR_DST}/postgres/run_add2BAD.sh" \
        "${VIDAR_DST}/postgres/run_readSEC.sh" \
        "${VIDAR_DST}/postgres/vidar.sql" \
        "${VIDAR_DST}/perl/vidar_add2BAD.pl" \
        "${VIDAR_DST}/perl/vidar_audit.pl" \
        "${VIDAR_DST}/perl/vidar_connectiontest.pl" \
        "${VIDAR_DST}/perl/vidar_readSEC.pl" \
        "${VIDAR_DST}/perl/vidar_sweepIPFW.pl" \
        "${VIDAR_DST}/scripts/vidar_start_postgres.sh" \
        "${VIDAR_DST}/scripts/vidar_stop.sh" \
        "${VIDAR_DST}/utils/switch_input.sh" 

    # Apply permissions for special cases.
    chmod 0755  \
        "${VIDAR_DST}/postgres/run_add2BAD.sh" \
        "${VIDAR_DST}/postgres/run_readSEC.sh" \
        "${VIDAR_DST}/postgres/vidar_add2BAD.sh" \
        "${VIDAR_DST}/postgres/vidar_audit.sh" \
        "${VIDAR_DST}/postgres/vidar_connectiontest.sh" \
        "${VIDAR_DST}/postgres/vidar_readSEC.sh" \
        "${VIDAR_DST}/postgres/vidar_sweepIPFW.sh" \
        "${VIDAR_DST}/perl/vidar_add2BAD.pl" \
        "${VIDAR_DST}/perl/vidar_audit.pl" \
        "${VIDAR_DST}/perl/vidar_connectiontest.pl" \
        "${VIDAR_DST}/perl/vidar_readSEC.pl" \
        "${VIDAR_DST}/perl/vidar_sweepIPFW.pl" \
        "${VIDAR_DST}/scripts/ipfw_good_table.sh" \
        "${VIDAR_DST}/scripts/ipfw_up.sh" \
        "${VIDAR_DST}/scripts/run_ipfw.sh" \
        "${VIDAR_DST}/scripts/run_sec.sh" \
        "${VIDAR_DST}/scripts/vidar_dumpBAD.sh" \
        "${VIDAR_DST}/scripts/vidar_healthcheck.sh" \
        "${VIDAR_DST}/scripts/vidar_importBAD.sh" \
        "${VIDAR_DST}/scripts/vidar_start_postgres.sh" \
        "${VIDAR_DST}/scripts/vidar_stop.sh" \
        "${VIDAR_DST}/sec/fixup_rules.sh" \
        "${VIDAR_DST}/utils/push.sh" \
        "${VIDAR_DST}/utils/randomip.pl" \
        "${VIDAR_DST}/utils/regex_array_check.pl" \
        "${VIDAR_DST}/utils/regex_check.pl" \
        "${VIDAR_DST}/utils/switch_input.sh" \
        "${VIDAR_DST}/utils/throt.pl" 

    # One more special exception  - the helper file vidar_ipfw_delete.sh
    # which should live in either the local libexec directory, when installed
    # in dev mode or the system libexec/vidar directory when installed in prod mode. 
    # Note that the sudoers.d/vidar entry has to track which location the
    # installation takes.
    # This function only installs the helper file.  See the function
    # vidar_sudoers_setup() below for the sudoers setup.

    info "Setting helper file vidar_ipfw_delete.sh in [${VIDAR_MODE}]."

    case "${VIDAR_MODE}" in
        dev)
            # File is already in the vidar libexec directory.  Just change
            # ownership and permissions
            info "Fixing dev helper at [${VIDAR_DST}/libexec/vidar_ipfw_delete.sh]"
            chown root:wheel "${VIDAR_DST}/libexec/vidar_ipfw_delete.sh"
            chmod 0755 "${VIDAR_DST}/libexec/vidar_ipfw_delete.sh"
            # Fix the libexec directory
            chown root:wheel "${VIDAR_DST}/libexec"
            chmod 0550 "${VIDAR_DST}/libexec"
            ;;
        prod)
            # Install the helper file in /usr/local/libexec/vidar/vidar_ipfw_delete.sh
            info "Fixing prod helper at [/usr/local/libexec/vidar/vidar_ipfw_delete.sh]"
            install -d -o root -g wheel -m 0755 /usr/local/libexec/vidar

            install -o root -g wheel -m 0550 \
               "${VIDAR_DST}/libexec/vidar_ipfw_delete.sh" \
               /usr/local/libexec/vidar/vidar_ipfw_delete.sh
              
            rm -f "${VIDAR_DST}/libexec/vidar_ipfw_delete.sh"
            rm -f "${VIDAR_DST}/libexec/.gitkeep"
            # Remove local libexec directory so there is no confusion.
            rmdir "${VIDAR_DST}/libexec"


            #mv "${VIDAR_DST}/libexec/vidar_ipfw_delete.sh" /usr/local/libexec/vidar/
            #chown root:wheel /usr/local/libexec/vidar/vidar_ipfw_delete.sh
            #chmod 0550 /usr/local/libexec/vidar/vidar_ipfw_delete.sh
            ;;
        *)
            warn "Incorrect parameter [${VIDAR_MODE}]"
            usage
            ;;
    esac

}


fix_runtime_environment() {
    info "Setting runtime environment in ${VIDAR_DST} tree."
    # Default to dev unless explicitly changed later.
    ( cd "${VIDAR_DST}"
        mkdir setupfiles
        # Find all setup files and make changes.
        # These have to be done inline so the variable values will transfer.
        for i in `grep -RHl --include '*.setup'  '@@@VIDAR_HOMEDIR@@@' *` 
        do 
            BASEFILE=$(basename ${i} '.setup') 
            BASEDIR=$(dirname ${i}) 
            OUTFILE="${BASEDIR}/${BASEFILE}"
            cat "${i}" | \
                sed -e "s]@@@VIDAR_HOMEDIR@@@]${VIDAR_DST}]g" \
                    -e "s]@@@VIDAR_ENVIRONMENT_TAG@@@]${VIDAR_ENVIRONMENT}]g" \
                     > "${OUTFILE}"
            info "Modified ${OUTFILE} for ${VIDAR_DST}"
            mv "${i}" setupfiles
            info "Remove setupfiles/${i} after installation."
        done

      chown -h root:"${VIDAR_GROUP}" "$VIDAR_ETC/vidar_env.sh"
      chmod 0644 "${VIDAR_ETC}/vidar_env.sh"
    )

    # If production (VIDAR_ENVIRONMENT=PRODUCTION), then
    # set the three main input logs to production locations.
    # This time, edit the files in place (-i extension)  with extension ".bak"
    # and delete the backup files if the command succeeds.
    if [ "X${VIDAR_ENVIRONMENT}" = "XPRODUCTION" ]
    then
        ( cd "${VIDAR_DST}/etc" || die "Can't find VIDAR_DST/etc."
            if sed -i .bak \
              -e 's|^export AUTHLOG=${VIDAR_INPUT}/auth\.log$|export AUTHLOG=/var/log/auth.log|' \
              -e 's|^export EMAILLOG=${VIDAR_INPUT}/maillog$|export EMAILLOG=/var/log/maillog|' \
              -e 's|^export NGINXLOG=${VIDAR_INPUT}/access\.log$|export NGINXLOG=/var/log/nginx/access.log|' \
                vidar_env.sh
            then
                rm vidar_env.sh.bak
                info "Modified vidar_env.sh for production locations."
            else
                info "ERROR Modifying  vidar_env.sh for production locations."
            fi
        )
    fi
}


create_runtime_dirs() {
    info "Creating runtime directories"

    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST/logs"
    install -d -o "$VIDAR_USER" -g "$VIDAR_GROUP" -m 0755 "$VIDAR_DST/pids"
}


show_all_vars() {

    echo "The following environment variables will be used:"
    echo
    echo "VIDAR_DB       =[${VIDAR_DB}]"
    echo "VIDAR_DST      =[${VIDAR_DST}]"
    echo "VIDAR_ETC      =[${VIDAR_ETC}]"
    echo "VIDAR_GROUP    =[${VIDAR_GROUP}]"
    echo "VIDAR_HOME     =[${VIDAR_HOME}]"
    echo "VIDAR_MODE     =[${VIDAR_MODE}]"
    echo "VIDAR_SRC      =[${VIDAR_SRC}]"
    echo "VIDAR_USER     =[${VIDAR_USER}]"
    echo "VIDAR_SCRIPTS  =[${VIDAR_SCRIPTS}]"
    echo
}


vidar_sudoers_setup() {
    info "Setting up vidar in /usr/local/etc/sudoers.d/vidar"
    # Following the logic in setting up the helper script above,
    # we want the sudoers.d/vidar entry to point to either
    # the local libexec/vidar_ipfw_delete.sh for a dev install
    # or to the /usr/local/libexec/vidar/vidar_ipfw_delete.sh
    # for a prod install.

    VIDAR_SUDOERSD=/usr/local/etc/sudoers.d        # The directory
    VIDAR_SUDOERSD_FILE="${VIDAR_SUDOERSD}/vidar"  # The file
    VISUDO="/usr/local/sbin/visudo"                # The validator 

    [ -x "$VISUDO" ] || die "visudo not found or not executable at [${VISUDO}]"
    [ -n "${VIDAR_DST:-}" ] || die "VIDAR_DST is not set in vidar_sudoers_setup()."

    install -d -o root -g wheel -m 0750 "$VIDAR_SUDOERSD"

    # ChatGPT recommends checking the sudoers.d/vidar file with visudo
    # so we do that first:

    tmpfile="$(mktemp ./vidar_sudoers.XXXXXX)" || die "mktemp file in vidar_sudoers_setup()."

    case "${VIDAR_MODE}" in
        dev)
            info "Fixing dev sudoers.d entry."
            cat > "$tmpfile" <<EOF
vidar ALL=(root) NOPASSWD: ${VIDAR_DST}/libexec/vidar_ipfw_delete.sh *
EOF
            ;;
        prod)
            info "Fixing prod sudoers.d entry."
            cat > "$tmpfile" <<EOF
vidar ALL=(root) NOPASSWD: /usr/local/libexec/vidar/vidar_ipfw_delete.sh *
EOF
            ;;
        *)
            warn "Incorrect parameter [${VIDAR_MODE}] in sudoers.d fixup fuction."
            usage
            ;;
    esac

    chown root:wheel "$tmpfile"
    chmod 0440 "$tmpfile"
    "$VISUDO" -c -f "$tmpfile" || {
        rm -f "$tmpfile"
        die "sudoers tmpfile validation failed in vidar_sudoers_setup()."
    }
    
    # Just replace any existing sudoers.d/vidar file
    if [ -f "${VIDAR_SUDOERSD}/vidar" ]
    then
        # Move it out of the way.
        mv "${VIDAR_SUDOERSD}/vidar" "${VIDAR_SUDOERSD}/vidar.OLD"
    fi

    # The same file is used for dev or prod.  It's the contents
    # of the entry in the file that matter.
    install -o root -g wheel -m 0440 "$tmpfile" "$VIDAR_SUDOERSD_FILE"

    info "Validating sudoers production file."
    "$VISUDO" -c -f "$VIDAR_SUDOERSD_FILE" || {
        warn "Sudoers production validation failed in vidar_sudoers_setup()."
        warn "Suggest restoring ${VIDAR_SUDOERSD}/vidar.OLD to ${VIDAR_SUDOERSD}/vidar" 
        die  "Check file manually with ${VISUDO} and try again."
    }
    rm -f "$tmpfile"

    rm -f "${VIDAR_SUDOERSD}/vidar.OLD"
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

    # Set an initial variable.
    WHEREAMI=$(pwd)
    echo "Current directory is ${WHEREAMI}."

    # VIDAR_SRC is the top level of the Vidar source tree, typically /home/vidar/src/vidar
    if [    -d "${WHEREAMI}/etc"      -a -d "${WHEREAMI}/input" \
         -a -d "${WHEREAMI}/libexec"  -a -d "${WHEREAMI}/postgres" \
         -a -d "${WHEREAMI}/scripts"  -a -d "${WHEREAMI}/sec" \
         -a -d "${WHEREAMI}/testdata" -a -d "${WHEREAMI}/utils" \
         -a -d "${WHEREAMI}/.git" ]
    then
    # Good chance we are in the source directory for Vidar.
      VIDAR_SRC=$(pwd)
      echo "Assuming VIDAR_SRC as ${VIDAR_SRC}"
    else
      echo
      warn "Directory [${WHEREAMI}] does not seem to be a complete and correct Vidar source dir."
      die "Check directory contents or perform a git clone in this directory."
       
    fi

    # VIDAR_HOME is the home directory of user vidar.
    VIDAR_HOME=/home/vidar

    # VIDAR_DST is the destination for a successful install.
    # The install depends on the VIDAR_MODE parameter passed.
    # The development default is VIDAR_HOME/dev.
    # The production default is /usr/local/vidar.

    if [ "X${VIDAR_MODE}" = "Xdev" ]
    then
        VIDAR_DST="${VIDAR_HOME}/dev"   # Development
    else
        VIDAR_DST=/usr/local/vidar    # Production
    fi
    
    # We need these two vars right now.
    VIDAR_ETC="${VIDAR_DST}/etc"
    VIDAR_SCRIPTS="${VIDAR_DST}/scripts"

    VIDAR_USER="vidar"
    VIDAR_GROUP="vidar"
    VIDAR_DB="vidar"

    check_required_commands

    show_all_vars

    ensure_vidar_user_and_group

    install_tree

    fix_runtime_environment

    create_runtime_dirs

    vidar_sudoers_setup

    info "Vidar base install complete"

    info "Next steps: database setup, rc/service setup"
}

main "$@"
