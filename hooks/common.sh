#
#  Common shell functions which may be used by any hook script
#
#  If you find that a distribution-specific hook script or two
# are doing the same thing more than once it should be added here.
#
#  This script also includes a logging utility which you're encouraged
# to use.
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
#    assert $LINENO "${verbose}"
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
#  Install a Debian package via apt-get.
#
installDebianPackage ()
{
    prefix=$1
    package=$2

    #
    # Log our options
    #
    logMessage "Installing Debian package ${package} to prefix ${prefix}"

    #
    #  We require a package + prefix
    #
    assert $LINENO "${package}"
    assert $LINENO "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert $LINENO -d ${prefix}

    #
    # Install the package
    #
    DEBIAN_FRONTEND=noninteractive chroot ${prefix} /usr/bin/apt-get --yes --force-yes install ${package}

}



#
#  Remove a Debian package.
#
removeDebianPackage ()
{
    prefix=$1
    package=$2

    #
    # Log our options
    #
    logMessage "Purging Debian package ${package} from prefix ${prefix}"

    #
    #  We require a package + prefix
    #
    assert $LINENO "${package}"
    assert $LINENO "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert $LINENO -d ${prefix}

    #
    # Purge the package
    #
    chroot ${prefix} /usr/bin/dpkg --purge ${package}

}


#
#  Install a CentOS4 package via yum
#
installCentOS4Package ()
{
    prefix=$1
    package=$2

    #
    # Log our options
    #
    logMessage "Installing CentOS4 ${package} to prefix ${prefix}"

    #
    #  We require a package + prefix
    #
    assert $LINENO "${package}"
    assert $LINENO "${prefix}"

    #
    # Prefix must be a directory.
    #
    assert $LINENO -d ${prefix}

    #
    # Install the package
    #
    chroot ${prefix} /usr/bin/yum -y install ${package}
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

