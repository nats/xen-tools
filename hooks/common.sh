#!/bin/sh
#
#  Common shell functions which may be used by any hook script
#
#  If you find that a distribution-specific hook script or two
# are doing the same thing more than once it should be added here.
#
#  This script also includes a logging utility which you're encouraged
# to use.
#
#  The routines here may be freely called from any role script(s) you
# might develop.
#
# Steve
# --
#



#
#  If we're running verbosely show a message, otherwise swallow it.
#
logMessage ()
{
    message="$*"

    if [ ! -z "${verbose}" ]; then
        echo $message
    fi
}



#
#  Test the given condition is true, and if not abort.
#
#  Sample usage:
#    assert "$LINENO" "${verbose}"
#
assert ()
{
    lineno="?"

    if [ -n "${LINENO}" ]; then
        # our shell defines variable LINENO, great!
        lineno=$1
        shift
    fi

    if [ ! $* ] ; then
        echo "assert failed: $0:$lineno [$*]"
        exit
    fi
}


#
#  Install a number of Debian packages via apt-get.
#
#  We take special care so that daemons shouldn't start after installation
# which they might otherwise do.
#
#  NOTE:  Function not renamed with trailing "s" for compatability reasons.
#
installDebianPackage ()
{
    prefix=$1
    shift
    #
    # Log our options
    #
    logMessage "Installing Debian packages $@ to prefix ${prefix}"

    runDebianCommand "$prefix" /usr/bin/apt-get --yes --force-yes install "$@"
}

runDebianCommand()
{
    prefix=$1
    shift

    #
    #  We require a package + prefix
    #
    assert "$LINENO" "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert "$LINENO" -d ${prefix}

    #
    #  Use policy-rc to stop any daemons from starting.
    #
    printf '#!/bin/bash\nexit 101\n' > ${prefix}/usr/sbin/policy-rc.d
    chmod +x ${prefix}/usr/sbin/policy-rc.d

    #
    # Disable the start-stop-daemon - this shouldn't be necessary
    # with the policy-rc.d addition above, however leaving it in
    # place won't hurt ..
    #
    disableStartStopDaemon ${prefix}

    #
    # Install the packages
    #
    TOMOUNT=$(cat /etc/mtab | grep -Ev "$prefix| / |/run" | cut -d ' ' -f 2 | sort)
    TOUMOUNT=$(cat /etc/mtab | grep -Ev "$prefix| / |/run" | cut -d ' ' -f 2 | sort -r)
    
    [ -e ${prefix}/etc/mtab -o -L ${prefix}/etc/mtab ] && NEEDS_MTAB=no || NEEDS_MTAB=yes
    [ $NEEDS_MTAB = "yes" ] && (
	cat /etc/mtab | grep -Ev "$prefix|/run" > ${prefix}/etc/mtab 
	sed -Ei 's#[^ ]+( / .*)#/dev/'${disk_device}'1\1#'  ${prefix}/etc/mtab
    )

    for DIR in $TOMOUNT ; do mount -o bind $DIR ${prefix}$DIR ; done
    DEBIAN_FRONTEND=noninteractive chroot ${prefix} "$@" ; RESULT=$?

    # Stop any processes that were left running
    FOUND=0
    for ROOT in /proc/*/root; do
    LINK=$(readlink $ROOT)
    if [ "x$LINK" != "x" ]; then
        if [ "x${LINK:0:${#prefix}}" = "x$prefix" ]; then
            # this process is in the chroot...
            PID=$(basename $(dirname "$ROOT"))
            kill "$PID"
            FOUND=1
        fi
    fi
    done

    # Wait for exit
    [ $FOUND = "1" ] && sleep 5

    # Unmount everything
    for DIR in $TOUMOUNT ; do umount ${prefix}$DIR ; done

    [ $NEEDS_MTAB = "yes" ] && chroot ${prefix} rm /etc/mtab

    #
    #  Remove the policy-rc.d script.
    #
    rm -f ${prefix}/usr/sbin/policy-rc.d

    #
    # Re-enable the start-stop-daemon
    #
    enableStartStopDaemon ${prefix}

    return $RESULT
}



#
# Disable the start-stop-daemon
#
disableStartStopDaemon ()
{
   local prefix="$1"
   assert "$LINENO" "${prefix}"
   local daemonfile="${prefix}/sbin/start-stop-daemon"

   mv "${daemonfile}" "${daemonfile}.REAL"
   echo '#!/bin/sh' > "${daemonfile}"
   echo "echo \"Warning: Fake start-stop-daemon called, doing nothing\"" >> "${daemonfile}"

   chmod 755 "${daemonfile}"
   logMessage "start-stop-daemon disabled / made a stub."
}



#
# Enable the start-stop-daemon
#
enableStartStopDaemon ()
{
   local prefix=$1
   assert "$LINENO" "${prefix}"
   local daemonfile="${prefix}/sbin/start-stop-daemon"

   #
   #  If the disabled file is present then enable it.
   #
   if [ -e "${daemonfile}.REAL" ]; then
       mv "${daemonfile}.REAL" "${daemonfile}"
       logMessage "start-stop-daemon restored to working order."
   fi

}



#
#  Remove the specified Debian packages.
#
#  NOTE:  Function not renamed with trailing "s" for compatibility reasons.
#
removeDebianPackage ()
{
    prefix=$1
    shift

    #
    # Log our options
    #
    logMessage "Purging Debian package ${package} from prefix ${prefix}"

    #
    #  We require a prefix
    #
    assert "$LINENO" "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert "$LINENO" -d ${prefix}

    #
    # Purge the packages we've been given.
    #
    chroot ${prefix} /usr/bin/apt-get remove --yes --purge "$@"

}


#
#  Install a CentOS4 package via yum
#
installCentOS4Package ()
{
    prefix=$1
    shift

    #
    # Log our options
    #
    logMessage "Installing CentOS4 $@ to prefix ${prefix}"

    #
    #  We require a package + prefix
    #
    assert "$LINENO" "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert "$LINENO" -d ${prefix}

    #
    # Install the package. A working /proc is required by yum
    #
    if [ ! -d ${prefix}/proc ]; then
        mkdir -p ${prefix}/proc
    fi
    mount -o bind /proc ${prefix}/proc
    mount -o bind /dev ${prefix}/proc
    # Run with a blank environment to prevent our environment settings 
    # from tripping up things invoked during package installation (eg, dracut)
    chroot ${prefix} env -i /usr/bin/yum -y install "$@" ; RESULT=$?
    umount ${prefix}/proc
    umount ${prefix}/dev

    return $RESULT
}


installZypperPackage ()
{
    prefix=$1
    package=$2

    #
    # Log our options
    #
    logMessage "Installing Zypper ${package} to prefix ${prefix}"

    #
    #  We require a package + prefix
    #
    assert "$LINENO" "${package}"
    assert "$LINENO" "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert "$LINENO" -d ${prefix}

    #
    # Install the package. Move uuidd out of the way to stop it starting 
    #
    local uuidd="${prefix}/usr/sbin/uuidd"
    test -e ${uuidd} && mv ${uuidd} ${uuidd}.REAL
    if [ ! -d ${prefix}/proc ]; then
        mkdir -p ${prefix}/proc
    fi
    mount -o bind /proc ${prefix}/proc
    chroot ${prefix} /usr/bin/zypper -n install ${package}
    umount ${prefix}/proc
    test -e ${uuidd}.REAL && mv ${uuidd}.REAL ${uuidd}
}



#
#  Install a package using whatever package management tool is available
#
installPackage ()
{
	prefix=$1
	package=$2

	if [ -x ${prefix}/usr/bin/apt-get ] ; then
		installDebianPackage "$@"

	elif [ -x ${prefix}/usr/bin/yum ] ; then
		installCentOS4Package "$@"

	elif [ -x ${prefix}/usr/bin/zypper ] ; then
		installZypperPackage "$@"

	else
		logMessage "Unable to install package ${package}; no package manager found"
	fi
}



#
#  Install a package upon a gentoo system via emerge.
#
# TODO: STUB
#
installGentooPackage ()
{
    prefix=$1
    package=$2

    #
    # Log our options
    #
    logMessage "Installing Gentoo package ${package} to prefix ${prefix}"

    logMessage "NOTE: Not doing anything - this is a stub - FIXME"

}


#
#  Run depmod on the installed modules
#
generateModulesDep ()
{
    prefix=$1
    logMessage "Generating module dependencies to prefix ${prefix}"
    chroot ${prefix} /sbin/depmod -a `ls -1 ${prefix}/lib/modules`
}

