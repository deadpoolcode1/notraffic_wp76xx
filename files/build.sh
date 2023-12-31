#!/bin/bash
#
# Copyright (c) 2011-2012 Wind River Systems, Inc.
#

# Let bitbake use the following env-vars as if they were pre-set bitbake ones.
# (BBLAYERS is explicitly blocked from this within OE-Core itself, though...)
export BB_ENV_EXTRAWHITE="http_proxy MACHINE DISTRO DL_DIR"

IFS='
    '

PATH=/usr/local/bin:/bin:/usr/bin
export PATH


UMASK=022
umask $UMASK

scriptdir=$(cd $(dirname ${0}); pwd)
WS="$scriptdir/../poky"

ALL_ARGS="$*"

# Some useful global variables
SWI_OK=0
SWI_ERR=1

usage()
{
    cat << EOF
Usage:
$0 <options ...>

  Global:
    -p <poky_dir>
    -o <meta-openembedded dir>
    -l <SWI meta layer>
    -x <linux repo directory>
    -m <SWI machine type>
    -b <build_dir>
    -t <number of bitbake tasks>
    -j <number of make threads>
    -r (enable preempt-rt kernel <Test-only. Not supported>)
    -g (enable Legato setup and build Legato images)
    -a (pass extra options for recipes, key=value separated by ::)
    -K <kernel provider>
    -e (enable build recovery image or normal image)
    -i <ima-config-file> (enable IMA build, pass full path to ima.conf as a parameter)
    -B Pass flags directly to bitbake (e.g. -vvv for verbose build)
    -E Enable extended SWI image (add additional developer packages)

  Machine swi-mdmXXXX:
    -q (enable Qualcomm Proprietary bin)
    -s (enable Qualcomm Proprietary source)
    -w <Qualcomm source directory (apps_proc)>
    -v <version of Qualcomm sources>
    -F <path to ar_yocto-cwe.tar.bz2>
    -M (enable mangoh meta layer)
    -Q (building for Qemu)

  Task control:
    -c (enable command line mode)
    -d (build the full debug image)
    -k (build the toolchain)
EOF
}

usage_and_exit()
{
    usage
    exit $1
}

if [ $# = 0 ]; then
    usage_and_exit 1
fi

# Default options
BD="$scriptdir/../build"
MACH=swi-mdm9x28
DEBUG=false
TASKS=4
THREADS=4
CMD_LINE=false
TOOLCHAIN=false
ENABLE_PROPRIETARY=false
ENABLE_PROPRIETARY_SRC=false
ENABLE_ICECC=false
ENABLE_EXT_SWI_IMG=false
ENABLE_LEGATO=false
ENABLE_META_MANGOH=false
DISTRO=poky-swi
KERNEL_PROVIDER=
X_OPTS=
PROD=
PROD_FAMILY=
ENABLE_RECOVERY=
QEMU=false
ENABLE_IMA=false
IMA_CONFIG=""
BB_FLAGS=""
SHARED_SSTATE=false
ENABLE_FX30=false

while getopts ":p:o:b:l:x:m:t:j:w:v:a:F:P:i:B:MecdrqsgkhEQGS" arg
do
    case $arg in
    p)
        WS=$(readlink -f $OPTARG)
        echo "Poky dir: $WS"
        ;;
    o)
        OE=$(readlink -f $OPTARG)
        echo "OE meta: $OE"
        ;;
    b)
        BD=$(readlink -f $OPTARG)
        echo "Build dir: $BD"
        ;;
    l)
        SWI=$(readlink -f $OPTARG)
        echo "SWI meta dir: $SWI"
        ;;
    x)
        LINUXDIR=$(readlink -f $OPTARG)
        echo "Linux repo dir: $LINUXDIR"
        ;;
    m)
        MACH=$OPTARG
        echo "SWI machine: $MACH"
        ;;
    d)
        DEBUG=true
        echo "Enable more packages for debugging"
        ;;
    t)
        TASKS=$OPTARG
        echo "Number of bitbake tasks $TASKS"
        ;;
    j)
        THREADS=$OPTARG
        echo "Number of make threads $THREADS"
        ;;
    a)
        X_OPTS="$X_OPTS $OPTARG"
        echo "Extra options added -  $OPTARG"
        ;;
    K)
        KERNEL_PROVIDER="$OPTARG"
        echo "Kernel provider: $KERNEL_PROVIDER"
        ;;
    e)
        ENABLE_RECOVERY="true"
        echo "Enable recovery image: $ENABLE_RECOVERY"
        ;;
    c)
        CMD_LINE=true
        echo "Enable command line mode"
        ;;
    q)
        ENABLE_PROPRIETARY=true
        echo "Enable Qualcomm Proprietary bin"
        ;;
    s)
        ENABLE_PROPRIETARY_SRC=true
        echo "Enable Qualcomm Proprietary source - overrides binary option"
        ;;
    w)
        WK=$(readlink -f $OPTARG)
        [ -n "$WK" ] || echo "warning: -w $OPTARG (for WK variable) doesn't resolve"
        ;;
    v)
        FW_VERSION=$OPTARG
        echo "FW Version: $FW_VERSION"
        ;;
    g)
        ENABLE_LEGATO="true"
        echo "With Legato"
        ;;
    k)
        TOOLCHAIN=true
        echo "Build toolchain"
        ;;
    h)
         ENABLE_ICECC=true
        echo "Build using icecc"
        ;;
    E)
        ENABLE_EXT_SWI_IMG=true
        echo "Sierra Wireless extended packages are enabled"
        ;;
    F)
        FIRMWARE_PATH=$(readlink -f $OPTARG)
        echo "Use FIRWARE_PATH=${FIRMWARE_PATH} to fetch ar_yocto-cwe.tar.bz2 binary"
        ;;
    M)
        ENABLE_META_MANGOH=true
        echo "With mangOH"
        ;;
    P)
        PROD=$OPTARG
        echo "SWI product: $PROD"
        PROD_FAMILY=${PROD%%[0-9]*}  #  ar758x -> ar;  wp76 -> wp ; ...
        [ "$PROD" == "$PROD_FAMILY" ] || echo "SWI product family: $PROD_FAMILY"
        ;;
    Q)
        QEMU=true
        echo "Building for QEMU"
        ;;
    S)
        SHARED_SSTATE=true
        echo "Enable shared sstate"
        ;;
    i)
        ENABLE_IMA=true
        IMA_CONFIG=$OPTARG
        echo "IMA is required."
        ;;
    B)
        BB_FLAGS=$OPTARG
        echo "bitbake flags: [$BB_FLAGS]"
        ;;
    ?)
        echo "$0: invalid option -$OPTARG" 1>&2
        usage_and_exit 1
        ;;
    esac
done

. ${WS}/oe-init-build-env $BD

## Check: bash

# Make sure that bash is set as default or build is not guaranteed to work
if [[ "$(basename $(readlink -f /bin/sh))" != "bash" ]]; then
    echo "Error: bash is not set as default provider for /bin/sh"
    echo "       build is not guaranteed to work, aborting"
    exit 1
fi

## Conf: bblayers.conf
declare -a LAYER_PATHS
declare -a LAYER_NAMES

enable_layer()
{
    local layer_name="$1"
    local layer_path="$2"
    local previous_layer="$3"

    if [ -z "$previous_layer" ]; then
        if [ ${#LAYER_NAMES[@]} -ge 1 ]; then
            previous_layer="${LAYER_NAMES[-1]}"
        else
            previous_layer="meta-yocto-bsp"
        fi

        previous_layer="$(echo "${previous_layer}" | sed 's#/#\\/#')"
    fi

    echo "+ layer: $layer_name"

    if command -v readlink >/dev/null; then
        layer_path="$(readlink -f "$layer_path")"
        if ! [ -e "$layer_path" ] ; then
            echo "  layer path ${layer_path} doesn't exist, skipping"
            return
        fi
    fi

    # Avoid duplication
    for other_path in ${LAYER_PATHS[@]}; do
        if [[ "$other_path" == "$layer_path" ]]; then
            echo "  duplicate ${layer_path}, skipping"
            return
        fi
    done

    LAYER_NAMES+=("$layer_name")
    LAYER_PATHS+=("$layer_path")

    grep -E "/$layer_name " $BD/conf/bblayers.conf > /dev/null
    if [ $? != 0 ]; then
        echo "         -> $layer_path"
        if ! sed -e '/'"$previous_layer"'/a\  '"$layer_path"' \\' -i $BD/conf/bblayers.conf; then
            echo "  error inserting layer $layer_name"
            exit 1
        fi
    fi
}

enable_layer_if_exists()
{
    local layer_path="$2"

    if [ -e "$layer_path" ] ; then
        enable_layer "$@"
    fi
}

# Enable the meta-oe layer
enable_layer "meta-oe" "$OE/meta-oe"

# Enable the meta-networking layer
enable_layer "meta-networking" "$OE/meta-networking"

# Enable the meta-python layer
enable_layer "meta-python" "$OE/meta-python"

# Enable the meta-gplv2 layer
if [ -e "$OE/../meta-gplv2" ]; then
    enable_layer "meta-gplv2" "$OE/../meta-gplv2"
else
    echo "Warning: meta-gplv2 repository not available"
fi

# Enable the personal_swi layer
if [ -e "$OE/../personal_swi" ]; then
    enable_layer "personal_swi" "$OE/../personal_swi"
else
    echo "Warning: personal_swi repository not available"
fi

# Enable the meta-swi layer
enable_layer "meta-swi/common" "$SWI/common"

case $MACH in
    swi-virt-* )
        enable_layer "meta-swi-virt" "$SWI/meta-swi-virt"
        ;;
    swi-mdm9* )
        # Enable the common meta-swi-mdm9xxx layer
        enable_layer "meta-swi/meta-swi-mdm9xxx" "$SWI/meta-swi-mdm9xxx"

        # Enable the meta-swi-mdmNNNN layer
        enable_layer "meta-swi/meta-$MACH" "$SWI/meta-$MACH"

        # Enable the meta-swi-mdmNNNN-PROD layer, if it exists
        if [ -n "$PROD" ] && [ -e "$SWI/meta-${MACH}-${PROD}" ]; then
            enable_layer "meta-swi/meta-$MACH-$PROD" "$SWI/meta-$MACH-$PROD"
        fi

        if [ $ENABLE_PROPRIETARY_SRC = true ] || [ $ENABLE_PROPRIETARY = true ]; then
            # Distro to poky-swi-ext to change SDKPATH
            DISTRO="poky-swi-ext"
        fi
        ;;
esac

# Enable proprietary layers: common
if [ $ENABLE_PROPRIETARY_SRC = true ] || [ $ENABLE_PROPRIETARY = true ]; then
    enable_layer "meta-swi-extras/common" "$scriptdir/../meta-swi-extras/common"

    enable_layer "meta-swi-extras/meta-$MACH" "$scriptdir/../meta-swi-extras/meta-$MACH"
fi

# Enable meta-mangoh layer
if [ $ENABLE_META_MANGOH = true ]; then
    enable_layer "meta-mangoh" "$scriptdir/../meta-mangoh"
fi

# Add new-style product-specific layer at the top level

if [ -n "$PROD_FAMILY" ]; then
    enable_layer_if_exists "meta-swi-$PROD_FAMILY" \
                           "$scriptdir/../meta-swi-$PROD_FAMILY/common"

    enable_layer_if_exists "meta-swi-$PROD" \
                           "$scriptdir/../meta-swi-$PROD_FAMILY/meta-swi-$PROD"

    if [ $ENABLE_PROPRIETARY = true ]; then
        enable_layer_if_exists "meta-swi-$PROD_FAMILY-extras" \
                               "$scriptdir/../meta-swi-$PROD_FAMILY-extras/common"

        enable_layer_if_exists "meta-swi-$PROD-extras" \
                               "$scriptdir/../meta-swi-$PROD_FAMILY-extras/meta-swi-$PROD-extras"

        if [ $ENABLE_PROPRIETARY_SRC = true ] ; then
            enable_layer_if_exists "meta-swi-$PROD-src" \
                                   "$scriptdir/../meta-swi-$PROD_FAMILY-extras/meta-swi-$PROD-src"
        else
            enable_layer_if_exists "meta-swi-$PROD-bin" \
                                   "$scriptdir/../meta-swi-$PROD_FAMILY-extras/meta-swi-$PROD-bin"
        fi
    fi
fi

# Enable proprietary layers: from sources
if [ $ENABLE_PROPRIETARY_SRC = true ]; then
    # Check that we have a source workspace to point to
    WK=${WK:-$WORKSPACE}
    WORKSPACE=${WK:?"Not set - must point to apps_proc of firmware build"}

    if [ ! -d ${WORKSPACE}/qmi ]; then
        echo WORKSPACE \(${WORKSPACE}\) appears not to be a valid source location
        echo WORKSPACE must point to apps_proc of firmware build
        exit 1
    fi

    echo "Workspace dir: $WORKSPACE"
    export WORKSPACE

    if [ -n "$FW_VERSION" ]; then
        echo "Workspace version: $FW_VERSION"
        export FW_VERSION
    fi

    # Add common mdm9xxx source layer
    enable_layer "meta-swi-extras/meta-swi-mdm9xxx-src" "$scriptdir/../meta-swi-extras/meta-swi-mdm9xxx-src"

    # Add machine-specific source layer
    enable_layer "meta-swi-extras/meta-$MACH-src" "$scriptdir/../meta-swi-extras/meta-$MACH-src"

    # Add product-specific source layer
    if [ -n "$PROD" ] && [ -e "$scriptdir/../meta-swi-extras/meta-$MACH-$PROD-src" ]; then
        enable_layer "meta-swi-extras/meta-$MACH-$PROD-src" \
            "$scriptdir/../meta-swi-extras/meta-$MACH-$PROD-src"
    fi

    # Add product-specific no-arch layer
    if [ -n "$PROD" ] && [ -e "$scriptdir/../meta-swi-extras/meta-$MACH-$PROD" ]; then
        enable_layer "meta-swi-extras/meta-$MACH-$PROD" \
            "$scriptdir/../meta-swi-extras/meta-$MACH-$PROD"
    fi

    copy_qmi_api() {
        cp -f $WORKSPACE/../modem_proc/sierra/src/dx/src/common/* $WORKSPACE/sierra/dx/common
        if [ $? != 0 ]; then
            echo "Unable to copy dx common files from modem_proc"
            exit 1
        fi
        cp -f $WORKSPACE/../modem_proc/sierra/src/dx/api/common/* $WORKSPACE/sierra/dx/common
        if [ $? != 0 ]; then
            echo "Unable to copy dx common API files from modem_proc"
            exit 1
        fi
        # We have to copy the qapi files from the modem dir
        cp -f $WORKSPACE/../modem_proc/sierra/src/qapi/src/common/* $WORKSPACE/sierra/qapi/common
        if [ $? != 0 ]; then
            echo "Unable to copy qapi common files from modem_proc"
            exit 1
        fi
        # Provice common qcsi files as a link to common qapi files
        rm -rf $WORKSPACE/sierra/qcsi/common && ( cd $WORKSPACE/sierra/qcsi && ln -s ../qapi/common common )
        if [ $? != 0 ]; then
            echo "Unable to provide qcsi common files from modem_proc"
            exit 1
        fi
        # We have to copy the NV files from the modem dir
        cp -f $WORKSPACE/../modem_proc/sierra/src/nv/src/common/* $WORKSPACE/sierra/nv/common
        if [ $? != 0 ]; then
            echo "Unable to copy NV common files from modem_proc"
            exit 1
        fi
        cp -f $WORKSPACE/../modem_proc/sierra/src/nv/api/common/* $WORKSPACE/sierra/nv/common
        if [ $? != 0 ]; then
            echo "Unable to copy NV API files from modem_proc"
            exit 1
        fi
    }

    if [[ "$MACH" == "swi-mdm9x15" ]]; then
        # We have to copy the dx files from the modem dir
        copy_qmi_api
    fi
fi

# Enable proprietary layers: from binaries
if [ $ENABLE_PROPRIETARY = true ]; then
    # Add common mdm9xxx binary layer
    enable_layer "meta-swi-extras/meta-swi-mdm9xxx-bin" "$scriptdir/../meta-swi-extras/meta-swi-mdm9xxx-bin"

    # Add machine-specific binary layer
    enable_layer "meta-swi-extras/meta-$MACH-bin" "$scriptdir/../meta-swi-extras/meta-$MACH-bin"

    # Add product-specific source layer
    if [ -n "$PROD" ] && [ -e "$scriptdir/../meta-swi-extras/meta-$MACH-$PROD-bin" ]; then
        enable_layer "meta-swi-extras/meta-$MACH-$PROD-bin" \
            "$scriptdir/../meta-swi-extras/meta-$MACH-$PROD-bin"
    fi
fi

## Conf: local.conf

set_option() {
    opt_name=$1
    opt_val=$2

    if grep "$opt_name =" $BD/conf/local.conf > /dev/null; then
        # Update entry
        echo "Updating $opt_name to $opt_val"
        sed -e "s/$opt_name = \".*//g" -i $BD/conf/local.conf
        echo "$opt_name = \"$opt_val\"" >> $BD/conf/local.conf
    else
        # Append
        echo "Adding option $opt_name with value $opt_val"
        echo "$opt_name = \"$opt_val\"" >> $BD/conf/local.conf
    fi
}

check_machine_name() {
    local machine=$1

    for layer_path in ${LAYER_PATHS[@]}; do
        machine_file=$(find "$layer_path" -name "${machine}.conf" -print)
        if [ -n "$machine_file" ]; then
            return 0
        fi
    done

    return 1
}

set_machine() {
    local machine=$1

    # Check if that machine is declared in the layers
    if ! check_machine_name $machine; then
        return 1
    fi

    if [ $QEMU = true ]; then
        MACH_LOCAL_CONF="${machine}-qemu"
    else
        MACH_LOCAL_CONF=$machine
    fi

    echo "Yocto machine: ${MACH_LOCAL_CONF}"
    sed -e 's:^\(MACHINE\).*:\1 = \"'${MACH_LOCAL_CONF}'\":' -i $BD/conf/local.conf
}

# Set IMA options. If IMA build is required, we need to add number
# of options to our global, static configuration file.
set_ima() {
    local ret=$SWI_OK

    # Always set this option, because it may have been set to something
    # else previously. This will enable or disable IMA build.
    set_option "IMA_BUILD" $ENABLE_IMA

    if [ "$ENABLE_IMA" == "true" ] ; then

        # IMA build should be enabled, make sure we know what the IMA config is.
        # Variable names here must match variable names in ima.conf .
        # We are adding these to global conf file, because this is
        # common information, and if we do not do it here, we would need
        # to source $IMA_CONFIG on multiple places, which would slow
        # down the build.

        if [ -f $IMA_CONFIG ] ; then

            echo "IMA config is specified, setting IMA options..."

            # Get variables from IMA configuration file.
            source $IMA_CONFIG

            # And write the ones we need to global configuration file.
            set_option "IMA_CONFIG" $IMA_CONFIG
            set_option "IMA_LOCAL_CA_X509" $IMA_LOCAL_CA_X509
            set_option "IMA_PRIV_KEY" $IMA_PRIV_KEY
            set_option "IMA_PUB_CERT" $IMA_PUB_CERT
            set_option "IMA_KERNEL_CMDLINE_OPTIONS" "$IMA_KERNEL_CMDLINE_OPTIONS"

            # Now, set some variables Legato build may need. Legato likes to use
            # different set of variables. This is perfectly fine, because we want
            # to decouple system from Legato, and use indipendently written
            # interfaces.

            # Set this to 1 if ENABLE_IMA=true, 0 otherwise.
            set_option "ENABLE_IMA" 1
            set_option "IMA_PUBLIC_CERT" $IMA_PUBLIC_CERT
            set_option "IMA_PRIVATE_KEY" $IMA_PRIVATE_KEY
            set_option "IMA_SMACK" $IMA_SMACK
        else
            echo "error: IMA is enabled, but IMA config file [$IMA_CONFIG] does not exist."
            ret=$SWI_ERR
        fi
    else
            # Unset everything. If not unset, some of these variables
            # could create problems later on in the build, because
            # they may get out of sync.
            set_option "IMA_CONFIG"
            set_option "IMA_LOCAL_CA_X509"
            set_option "IMA_PRIV_KEY"
            set_option "IMA_PUB_CERT"
            set_option "IMA_KERNEL_CMDLINE_OPTIONS"
            set_option "ENABLE_IMA" 0
            set_option "IMA_PUBLIC_CERT"
            set_option "IMA_PRIVATE_KEY"
            set_option "IMA_SMACK"
    fi

    return $ret
}

# Setup FX30 related variables
set_fx30() {

    if [ "x${PROD}" = "xfx30" ] ; then
        set_option "ENABLE_FX30" true
    else
        set_option "ENABLE_FX30"
    fi

    return 0
}

# Tune local.conf file
if [ -n "${PROD}" ]; then
    if [ -n "$ENABLE_RECOVERY" ]; then
        if ! set_machine "${MACH}-${PROD}-rcy"; then
            # If <MACH>-<PROD> is not available, fallback to <MACH>
            set_machine "${MACH}-rcy"
        fi
    elif ! set_machine "${MACH}-${PROD}"; then
        # If <MACH>-<PROD> is not available, fallback to <MACH>
        set_machine "${MACH}"
    fi
else
    set_machine "${MACH}"
fi

if [ -z "$YOCTO_MAJOR" ]; then
    YOCTO_MAJOR=$(git --git-dir=$WS/.git describe --tags --match 'yocto-*' | sed 's/yocto-\([0-9]*\)\.\([0-9]*\).*/\1/g')
fi
if [ -z "$YOCTO_MINOR" ]; then
    YOCTO_MINOR=$(git --git-dir=$WS/.git describe --tags --match 'yocto-*' | sed 's/yocto-\([0-9]*\)\.\([0-9]*\).*/\2/g')
fi

grep -E "SOURCE_MIRROR_URL" $BD/conf/local.conf > /dev/null
if [ $? != 0 ]; then

    # Determine source mirrors
    if [ -e "$scriptdir/../downloads" ]; then
        # Use the downloads/ directory if available
        SOURCE_MIRROR_URL="${SOURCE_MIRROR_URL:-"file://$scriptdir/../downloads"}"
    elif grep -q "sierrawireless.local" /etc/resolv.conf; then
        # Internal SWI network

        # Use internal SWI download mirror
        SOURCE_MIRROR_URL="${SOURCE_MIRROR_URL:-"http://get.legato/yocto/mirror/"}"

        # Use shared sstate by default
        SSTATE_MIRROR_URL="${SSTATE_MIRROR_URL:-"http://get.legato/yocto/sstate/yocto-${YOCTO_MAJOR}.${YOCTO_MINOR}"}"
    else
        # External network

        # Use official Yocto mirror
        SOURCE_MIRROR_URL="${SOURCE_MIRROR_URL:-"https://downloads.yoctoproject.org/mirror/sources/"}"

        # Use external SWI download mirror
        EXTRA_MIRROR_OPTS='PREMIRRORS_prepend = \" \\\n'
        EXTRA_MIRROR_OPTS+='    https?$://.*/.* https://get.legato.io/yocto/mirror/ \\n \\\n'
        EXTRA_MIRROR_OPTS+='    git://.*/.*     https://get.legato.io/yocto/mirror/ \\n \\\n'
        EXTRA_MIRROR_OPTS+='\"\n'
    fi

    if [[ "$SHARED_SSTATE" == "true" ]] && [ -n "$SSTATE_MIRROR_URL" ]; then
        EXTRA_MIRROR_OPTS+='SSTATE_MIRRORS = \"'
        EXTRA_MIRROR_OPTS+='    file://.*'
        EXTRA_MIRROR_OPTS+='    '"${SSTATE_MIRROR_URL}"'/PATH;downloadfilename=PATH'
        EXTRA_MIRROR_OPTS+='\"\n'
    fi

    sed -e '/^#DL_DIR/a\SOURCE_MIRROR_URL ?= \"'"$SOURCE_MIRROR_URL"'\"\nINHERIT += \"own-mirrors\"\nBB_GENERATE_MIRROR_TARBALLS = \"1\"\n'"$EXTRA_MIRROR_OPTS"'BB_NO_NETWORK = \"0\"\nWORKSPACE = \"'"${WORKSPACE}"'\"\nLINUX_REPO_DIR = \"'"${LINUXDIR}"'\"\nDISTRO = \"'"${DISTRO}"'\"' -i $BD/conf/local.conf
fi
sed -e 's:^#\(BB_NUMBER_THREADS\).*:\1 = \"'"$TASKS"'\":' -i $BD/conf/local.conf
sed -e 's:^#\(PARALLEL_MAKE\).*:\1 = \"-j '"$THREADS"'\":' -i $BD/conf/local.conf

set_option "LEGATO_BUILD" $ENABLE_LEGATO

# Set all IMA related build options
set_ima
if [ $? != $SWI_OK ]; then exit 1 ; fi

# Set all FX30 related build options
set_fx30
if [ $? != $SWI_OK ]; then exit 1 ; fi

if [ -n "$FW_VERSION" ]; then
    FW_VERSION_ENTRY=$(grep "FW_VERSION =" $BD/conf/local.conf)
    if [ $? != 0 ]; then
        # Append
        sed -e '/^WORKSPACE/a\FW_VERSION = \"'"${FW_VERSION}"'\"\n' -i $BD/conf/local.conf
    else
        CURRENT_FW_VERSION=$(echo $FW_VERSION_ENTRY | sed -e 's/FW_VERSION = \"\(.*\)\"/\1/g')
        if [[ "$FW_VERSION" != "$CURRENT_FW_VERSION" ]]; then
            # Update entry
            echo "Updating FW_VERSION from '${CURRENT_FW_VERSION}' to '${FW_VERSION}'"
            sed -e 's/FW_VERSION = \".*\"/FW_VERSION = \"'"${FW_VERSION}"'\"/g' -i $BD/conf/local.conf
        else
            echo "Keeping FW_VERSION '${FW_VERSION}'"
        fi
    fi
fi

set_option "ROOTFS_VERSION" $ROOTFS_VERSION

# Add or update extra options
if [ -n "$X_OPTS" ]
then
    EXTRA_OPTS=$(echo $X_OPTS | sed -e "s/\:\:/ /g")
    for OPT in $EXTRA_OPTS
    do
        opt_name=$(echo $OPT | cut -d"=" -f1)
        opt_val=$(echo $OPT | cut -d"=" -f2-)

        set_option $opt_name $opt_val
    done
fi

# Kernel provider
if [ -z "$KERNEL_PROVIDER" ]; then
    case $MACH in
        swi-mdm9x15 )
            KERNEL_PROVIDER="linux-yocto"
            ;;
        swi-mdm9* )
            KERNEL_PROVIDER="linux-quic"
            ;;
        * )
            KERNEL_PROVIDER="linux-yocto"
            ;;
    esac
fi

grep -E "PREFERRED_PROVIDER_virtual\/kernel" $BD/conf/local.conf > /dev/null
if [ $? != 0 ]; then
    echo "PREFERRED_PROVIDER_virtual/kernel = \"${KERNEL_PROVIDER}\"" >> $BD/conf/local.conf
else
    sed -e 's:^\(PREFERRED_PROVIDER_virtual\/kernel\).*:\1 = \"'${KERNEL_PROVIDER}'\":' -i $BD/conf/local.conf
fi

# IceCC
if [ $ENABLE_ICECC = true ]; then
    if ! grep icecc $BD/conf/local.conf > /dev/null; then
        echo 'INHERIT += "icecc"' >> $BD/conf/local.conf
        echo 'ICECC_PARALLEL_MAKE = "-j 20"' >> $BD/conf/local.conf
        echo 'ICECC_USER_PACKAGE_BL = "ncurses e2fsprogs libx11 gmp libcap perl busybox lk libgpg-error libarchive"' >> $BD/conf/local.conf
    fi
fi

# SWI extended packages.
set_option "EXT_SWI_IMG" $ENABLE_EXT_SWI_IMG
if [ $ENABLE_EXT_SWI_IMG = true ] ; then
    # Not supported for deployment for various reasons, warn the users.
    echo "warning: You are building debug image not intended for deployment. Use it at your own risk."
fi

# Initramfs
case $MACH in
    swi-mdm* )
        set_option 'INITRAMFS_IMAGE_BUNDLE' '1'
        if test x$ENABLE_RECOVERY = "xtrue"; then
            set_option 'INITRAMFS_IMAGE' "mdm-image-recovery"
        else
            set_option 'INITRAMFS_IMAGE' "${MACH#swi-}-image-initramfs"
        fi
        ;;
    swi-virt* )
        set_option 'INITRAMFS_IMAGE_BUNDLE' '1'
        set_option 'INITRAMFS_IMAGE' "swi-virt-image-initramfs"
        ;;
esac

# Firmware Path
set_option 'FIRMWARE_PATH' "${FIRMWARE_PATH}"

# Remove GNUTLS
set_option 'PACKAGECONFIG_remove' "gnutls"

cd $BD

# Set PACKAGE_CLASSES
sed -e 's:^\(PACKAGE_CLASSES\).*:\1 = \"package_ipk\":' -i $BD/conf/local.conf

# Command line
if [ $CMD_LINE = true ]; then
    /bin/bash
    exit $?
fi

# Toolchain
if [ $TOOLCHAIN = true ]; then
    case $MACH in
       * )
           bitbake ${BB_FLAGS} meta-toolchain-swi
           ;;
    esac
    exit $?
fi

# Images
echo -n "Build image of "
if [ $DEBUG = true ]; then
    echo "dev rootfs (for $MACH)."
    case $MACH in
        swi-mdm* )
            bitbake ${BB_FLAGS} ${MACH#swi-}-image-dev
            ;;
        swi-virt* )
            bitbake ${BB_FLAGS} swi-virt-image-dev
            ;;
        * )
            bitbake ${BB_FLAGS} core-image-dev
            ;;
    esac
    exit $?
else
    echo "minimal rootfs (for $MACH)."
    case $MACH in
        swi-mdm* )
            if test x$ENABLE_RECOVERY = "xtrue"; then
                bitbake ${BB_FLAGS} mdm-image-recovery
            else
                bitbake ${BB_FLAGS} ${MACH#swi-}-image-minimal
            fi
            ;;
        swi-virt* )
            bitbake ${BB_FLAGS} swi-virt-image-minimal
            ;;
        * )
            bitbake ${BB_FLAGS} core-image-minimal
            ;;
    esac
    exit $?
fi

