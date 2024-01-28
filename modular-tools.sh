#!/bin/bash

# source this script
# or run with argument "all"

# References:
# https://docs.legato.io/latest/basicBuild.html
# https://github.com/mangOH/mangOH
# https://github.com/legatoproject/legato-af/blob/master/README.md
VAR_OUTPUT_IMAGE_NAME=Release16_wp76_img
VAR_MODEM_IMAGE_NAME=leaf-data/current/wp76-modem-image/9999999_9907152_SWI9X07Y_02.37.03.00_00_GENERIC_002.095_000.spk 
#VAR_LEGATO_IMAGE_NAME=legato-src/legato/build/wp76xx/legato.cwe
VAR_LEGATO_IMAGE_NAME=legato.cwe
VAR_YOCTO_IMAGE_NAME=build_bin/tmp/deploy/images/swi-mdm9x28-wp/yocto_wp76xx.4k.cwe
VAR_LEAF_BASE_PACKAGE=swi-wp76_6.0.0

sanity_fix()
{
        file="poky/meta/conf/sanity.conf"
        line='INHERIT += "sanity"'
        modified_line='#INHERIT += "sanity"'

        if grep -q "$line" "$file"; then
                echo "The line '$line' exists in the file."
                if grep -q "$modified_line" "$file"; then
                        echo "The line '$modified_line' already exists and is commented out."
                else
                        sed -i "s/$line/$modified_line/g" "$file"
                        echo "The line '$line' has been modified to '$modified_line'."
                fi
        else
                echo "The line '$line' does not exist in the file."
        fi
}

help()
{
	echo "make_image_binary - make single update image from built sources, located under build_image"
	echo "leaf_setup - setup leaf envirunment, neads to be done at initial installation, and every time we switch leaf version"
	echo "yocto_download - gets latest Yocto sources from Sierra"
	echo "yocto_build - Build Yocto, notice to issue this only after downloading and patching"
	echo "legato_download - gets latest Legato sources from Sierra"
	echo "flash_image - flash release image to local device"
	echo "view_build_details - show image details" 
	echo "apply_patches - apply all patches on top of Yocto and Sierra"
	echo "onetime_setup_env - install needed tools for building yocto, do one time only" 
	echo "create_secureboot_signkey - generate key and store in library keys"
	echo "sign_images_with_client_key - signes images with client key"
	echo "flash_image_via_ssh - download the image to device via ssh and updates the image"
	echo "notice that all commands starting with _ needs to be run from the leaf shell"
}

android_signature_add() 
{
	ANDROID_SIGNING_DIR=build_bin/tmp/sysroots-components/x86_64/android-signing-native/usr/share/android-signing
	local image_type=$1
	local unsigned_image_path=$2
	local signed_image_path=$3
	${ANDROID_SIGNING_DIR}/verity/boot_signer $image_type \
	${unsigned_image_path} \
	keys/testkey.pk8 \
	keys/testkey.x509.pem \
	${signed_image_path}
 	# append cert chain if exists
 	if [ -e ${ANDROID_SIGNING_DIR}/security/AttestationCA.der ]; then
 		cat ${ANDROID_SIGNING_DIR}/security/AttestationCA.der >> ${signed_image_path}
 	fi
 	if [ -e ${ANDROID_SIGNING_DIR}/security/RootCA.der ]; then
		cat ${ANDROID_SIGNING_DIR}/security/RootCA.der >> ${signed_image_path}
 	fi
}

sign_images_with_client_key()
{
	# Define the paths to the keys
	pk8_key="keys/testkey.pk8"
	x509_key="keys/testkey.x509.pem"

	# Check if both keys exist
	if [[ -f "$pk8_key" && -f "$x509_key" ]]; then
 		# Both keys exist, proceed with the signing process
 		echo "Both keys exist. Proceeding with image signing..."
 	else
 		# At least one of the keys is missing
 		echo "No keys, please first generate keys"
 		return 1  # Exit the function with an error status
 	fi
	#sign boot image
 	android_signature_add boot build_bin/tmp/deploy/images/swi-mdm9x28-wp/boot-yocto-mdm9x28.4k.unsigned.img build_bin/tmp/deploy/images/swi-mdm9x28-wp/boot-yocto-mdm9x28.4k.img
 	android_signature_add aboot build_bin/tmp/deploy/images/swi-mdm9x28-wp/appsboot.mbn.unsigned build_bin/tmp/deploy/images/swi-mdm9x28-wp/appsboot.mbn
 	pushd .


 	dir_name="signed"
	if [ -d "$dir_name" ]; then
 		rm -rf "$dir_name"
		echo "Directory '$dir_name' has been removed."
 	else
 		echo "Directory '$dir_name' does not exist, so it was not removed."
 	fi
	mkdir signed
	cd signed
	cp ../build_bin/tmp/deploy/images/swi-mdm9x28-wp/boot-yocto-mdm9x28.4k.img .
	cp ../build_bin/tmp/deploy/images/swi-mdm9x28-wp/appsboot.mbn .
	cp ../build_bin/tmp/sysroots-components/x86_64/cwetool-native/usr/bin/hdrcnv hdrcnv_cwetool
	cp ../personal_swi/files/yoctocwetool.sh .
	cp  ../build_bin/tmp/deploy/images/swi-mdm9x28-wp/mdm9x28-image-minimal-swi-mdm9x28-wp.ubi .
	cp ../personal_swi/files/swi-key-cwe.sh .
	echo "SWI9X07Y_02.37.10.00" > version_file.txt
	./yoctocwetool.sh -pid '9X28' -platform '9X28' -o yocto.cwe -fbt appsboot.mbn -vfbt version_file.txt -kernel boot-yocto-mdm9x28.4k.img -vkernel version_file.txt -rfs mdm9x28-image-minimal-swi-mdm9x28-wp.ubi -vrfs version_file.txt
	./swi-key-cwe.sh ../keys/testkey.x509.pem 9X28 RFS0	
	popd
}

create_secureboot_signkey()
{
	# Define the name of the directory and file pattern
	dir_name="keys"
	file_pattern="testkey.*"

	# Check if the directory exists and remove it
	if [ -d "$dir_name" ]; then
    		rm -rf "$dir_name"
    		echo "Directory '$dir_name' has been removed."
	else
    		echo "Directory '$dir_name' does not exist, so it was not removed."
	fi

	# Check if files matching the pattern exist and remove them
	if ls $file_pattern 1> /dev/null 2>&1; then
    		rm -f $file_pattern
    		echo "Files matching '$file_pattern' have been removed."
	else
    		echo "No files matching '$file_pattern' found, so none were removed."
	fi
	build_bin/tmp/sysroots-components/x86_64/android-signing-native/usr/share/android-signing/make_key testkey  '/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'
	mkdir keys
	mv testkey.* keys	
}

onetime_setup_env()
{
	mkdir -p ~/.bin
	PATH="${HOME}/.bin:${PATH}"
	curl https://storage.googleapis.com/git-repo-downloads/repo-1 > ~/.bin/repo
	chmod a+rx ~/.bin/repo
	sed -i 's/env python/env python2/g' ~/.bin/repo
	wget https://downloads.sierrawireless.com/tools/leaf/leaf_latest.deb -O /tmp/leaf_latest.deb  
	sudo apt install /tmp/leaf_latest.deb
	leaf init
	leaf search wp76
	leaf setup -p swi-wp76_6.0.0	
}

leaf_setup()
{
	echo "setup leaf envirunment, neads to be done at initial installation, and every time we switch leaf version"
	leaf init
	leaf search wp76
	leaf setup -p $VAR_LEAF_BASE_PACKAGE
	leaf profile -v
}

yocto_download()
{
	echo "gets latest Yocto sources from Sierra"
	leaf getsrc swi-linux
}


append_layer()
{
#!/bin/bash

# Path to the bblayers.conf file
CONF_FILE="build_bin/conf/bblayers.conf"

# Get the current working directory as the base path
BASE_PATH=$(pwd)

# Check if personal_swi/ is already in the file
if grep -q "${BASE_PATH}/personal_swi \\\\" "$CONF_FILE"; then
    echo "personal_swi/ is already in the BBLAYERS."
else
    # Add personal_swi/ to the BBLAYERS
    sed -i "/BBLAYERS ?= \"/a \ \ ${BASE_PATH}/personal_swi \\\\" "$CONF_FILE"
    echo "Added personal_swi/ to the BBLAYERS."
fi
cp personal_swi/files/startlegato.sh meta-swi/common/recipes-legato/legato-init/legato-init/startlegato.sh
}
yocto_build()
{
append_layer
make
}

legato_download()
{
	echo "gets latest Legato sources from Sierra"
	leaf getsrc swi-legato
}

make_image_binary()
{
	echo "building single update image from already built images"
	#leaf shell
	swicwe -o $VAR_OUTPUT_IMAGE_NAME.spk -c $VAR_LEGATO_IMAGE_NAME $VAR_YOCTO_IMAGE_NAME -r
}

flash_image_via_ssh()
{
	scp Release16_wp76_img.spk root@192.168.2.2:/tmp/
	ssh root@192.168.2.2 '/legato/systems/current/bin/fwupdate download /tmp/Release16_wp76_img.spk'
}

flash_image()
{
	echo "flash release image to local device"
	VAR_PORT_NAME=$(find /dev/serial/by-id/  -name 'usb-Sierra_Wireless__Incorporated_Sierra_Wireless_WP7*' -a  -name '*if00-port0')
	if [ -z "$VAR_PORT_NAME" ]; then 
		echo "error, no device found" 
		break
	fi
	swiflash -p $VAR_PORT_NAME -m "WP76XX" -i $VAR_OUTPUT_IMAGE_NAME.spk
}

flash_image_fwdwl()
{
	sudo systemctl stop ModemManager
	pushd .
	cd personal_swi/files/
	./fwdwl-litehostx86_64 -f "./" -s ../Release16_wp76_img.spk  -d /dev/ttyUSB1 -p /dev/cdc-wdm1 -c QMI -m 4
	popd
}

view_build_details()
{
	echo "show image details"
	leaf profile -v
}

if [ -n "$*" ]; then
	eval "$*" # execute arguments
	#echo $* finished, ret=$?
else
	if [ "$0" != "$BASH_SOURCE" ]; then
		help
	else
		echo $BASH_SOURCE - a library of Sierra, mangOH, legato and yocto tools
		help
	fi
fi
