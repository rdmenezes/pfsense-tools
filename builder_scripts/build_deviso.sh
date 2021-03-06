#!/bin/sh
#
# Common functions to be used by build scripts
#
#  build_deviso.sh
#  Copyright (C) 2004-2009 Scott Ullrich
#  All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#  
#  1. Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#  
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  
#  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
#  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
#  AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#  AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
#  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.
#
# Crank up error reporting, debugging.
#  set -e 
#  set -x

# Suck in local vars
. ./pfsense_local.sh

# Suck in script helper functions
. ./builder_common.sh

export MODULES_OVERRIDE="i2c ipmi acpi ndis ipfw ipdivert dummynet fdescfs cpufreq opensolaris zfs glxsb runfw"

# This should be run first
launch

# Make sure source directories are present.
ensure_source_directories_present

# Ensure binaries are present that builder system requires
install_required_builder_system_ports

# Check if we need to force a ports rebuild
check_for_forced_pfPorts_build

# Clean up items that should be cleaned each run
freesbie_clean_each_run

# Output build flags
print_flags

# Add etcmfs and rootmfs to the EXTRAPLUGINS plugins used by freesbie2
export EXTRAPLUGINS="${EXTRAPLUGINS:-} rootmfs varmfs etcmfs customroot"

export SRC_CONF="${BUILDER_SCRIPTS}/conf/src.conf.developer.$FREEBSD_VERSION"

export IS_DEV_ISO=yo

export PRUNE_LIST=""

export KERNELCONF="${BUILDER_SCRIPTS}/conf/pfSense_Dev.$FREEBSD_VERSION"

# Suck in script helper functions
. ./builder_common.sh

# Install BSDInstaller
rebuild_and_install_bsdinstaller

# Update FreeBSD sources and install custom patches
if [ "$BUILDER_AUTO_UPDATE_APPLY_PATCHES" = "YES" ]; then
	update_freebsd_sources_and_apply_patches
else
	echo ">>> BUILDER_AUTO_UPDATE_APPLY_PATCHES is set to no.  Skipping builder update and patches."
fi

# Allow old CVS_CO_DIR to be deleted later
if [ -d $CVS_CO_DIR ]; then
	chflags -R noschg $CVS_CO_DIR
fi

# Checkout a fresh copy from pfsense cvs depot
update_cvs_depot

# Calculate versions
export version_kernel=`cat $CVS_CO_DIR/etc/version_kernel`
export version_base=`cat $CVS_CO_DIR/etc/version_base`
export version=`cat $CVS_CO_DIR/etc/version`

# Build world, kernel and install
echo ">>> Building world and kernels for DevISO... $FREEBSD_VERSION  $FREEBSD_BRANCH ..."
make_world

# Build SMP, Embedded (wrap) and Developers edition kernels
echo ">>> Building all extra kernels... $FREEBSD_VERSION  $FREEBSD_BRANCH ..."
build_all_kernels

# Add extra pfSense packages
echo ">>> Phase install_custom_packages"
install_custom_packages
echo ">>> Phase set_image_as_cdrom"
set_image_as_cdrom

echo ">>> Searching and installing ports..."
PKG_INSTALL_PORTSPFS="/usr/ports/sysutils/bsdinstaller /usr/ports/sysutils/grub /usr/ports/devel/git"
install_pkg_install_ports

install_pkg_install_ports

# Add extra files such as buildtime of version, bsnmpd, etc.
echo ">>> Phase populate_extra..."
cust_populate_extra

# Add installer bits
cust_populate_installer_bits

# Overlay pfsense checkout on top of FreeSBIE image
# using the customroot plugin
echo ">>> Merging extra items..."
freesbie_make extra

# Overlay host binaries
cust_overlay_host_binaries
check_for_zero_size_files

# Check for custom config.xml
cust_install_config_xml

# Ensure config.xml exists
copy_config_xml_from_conf_default

# Test PHP installation
test_php_install

# Check to see if we have a healthy installer
ensure_healthy_installer

# Setup dev_iso specific items
setup_deviso_specific_items

# Create md5 summary file listing checksums
create_md5_summary_file

# Prepare /usr/local/pfsense-clonefs
echo ">>> Cloning filesystem..."
freesbie_make clonefs

# Ensure /home exists
mkdir -p $CLONEDIR/home

# Finalize iso
echo ">>> Finalizing iso..."
freesbie_make iso

# Check for zero sized files.  loader.conf is one of the culprits.
check_for_zero_size_files
report_zero_sized_files

# Email that the operation has completed
email_operation_completed

# Run final finish routines
finish
