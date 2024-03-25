# personal SWI
contains meta-layer for additions and modifications to the default Yocto build

# Build station requirements
1. OS: Ubuntu 18.04 (tested on 18.04). Should also work on 20.04, will not work on 22.04
2. CPU: No hard limit but intel i5  or better is preferred 
3. RAM: minimum 8GB
4. Disc available: minimum: 80GB 


# initial code pull

1. Accept legato licence online. See: https://docs.legato.io/latest/toolsGitHub.html

2. Install repo:
 

    mkdir ~/wp76xx_yocto3

    cd ~/wp76xx_yocto3

    curl https://storage.googleapis.com/git-repo-downloads/repo-1 > ~/bin/repo

    chmod a+x ~/bin/repo

    python3 ~/.bin/repo init -u ssh://git@github.com/legatoproject/manifest -m mdm9x28/tags/SWI9X07Y_03.01.07.00/linux.xml -g default,-cache,proprietary ; python3 ~/.bin/repo sync   

    git clone git@github.com:deadpoolcode1/notraffic_wp76xx.git -b yocto3 personal_swi

    cp personal_swi/modular-tools.sh .

    sudo git config --system --add safe.directory '*'

3. Install extra build tools


    sudo rm /bin/sh

    sudo ln -s /bin/bash /bin/sh

    sudo apt -y install chrpath gawk texinfo openjdk-8-jdk python-pip

    sudo apt -y cpp diffstat g++ gcc build-essential

    ### Install swicwe

    wget https://downloads.sierrawireless.com/tools/swicwe/swicwe_latest.deb -O /tmp/swicwe_latest.deb

    sudo apt-get install /tmp/swicwe_latest.deb


# build image

    . modular-tools.sh yocto_build
    
    . modular-tools.sh sign_images_with_client_key
    
    . modular-tools.sh make_image_binary

# flash image to device

    ./fdt2.exe -f Release17_wp76_img.spk

notice to download fdt2 and required drivers from Sierra site

# flash image Linux

    sudo personal_swi/files//fwdwl-litehostx86_64 -f "./" -s Release17_wp76_img.spk  -d /dev/ttyUSB1 -p /dev/cdc-wdm1 -c QMI -m 4

Or:

    . modular-tools.sh flash_image_via_ssh



# accessing device

ssh root@10.5.0.4
root

# reading ADC

cm adc read EXT_ADC0


#controlling GPIO

use standard Linux userspace commands

pins are named mapped to:

/sys/bus/platform/drivers/personal_station-pm/soc\:personal_station-pm/

 12V_TZ

 JETSON_RESET

 ROUTER_RESET

 SYS_PWR_OFF

 TP1

 TP2 

# modifying Yocto build

all Yocto related modifications are done under layer "personal_swi"

# overriding default openssl and openvpn

1. Find `.bb` file with recipe for the correct pkg (openvpn, openssl et..) 
2. Change file name to include the correct version
3. Fix checksum in the `.bb` file for the newly downloaded source code
4. Run the following commands for updating your installed pkg


    make dev
    bitbake -c clean openvpn
    bitbake -c cleansstate openvpn
    bitbake -c compile openvpn

5. Build the yocto image again


# flash via ssh

    scp -oHostKeyAlgorithms=+ssh-rsa Release17_wp76_img.spk root@10.5.0.4:/tmp/
    ssh -oHostKeyAlgorithms=+ssh-rsa root@10.5.0.4 '/legato/systems/current/bin/fwupdate download /tmp/Release17_wp76_img.spk'

or use: `. modular-tools.sh flash_image_via_ssh`

# Hard flash to factory reset
1. Requires Windows PC
2. Install sierra driver, and reboot afterwards. https://source.sierrawireless.com/resources/airprime/software/airprime-em_mc-series-windows-drivers-qmi-build-latest-release/
3. Install Sierra FDT. https://source.sierrawireless.com/resources/airprime/software/fdt/#sthash.jTelv4Yp.dpbs
4. Connect WP76** device to the windows PC over usb and flash your firmware using FDT. E.G: `.\fdt2.exe -f .\Release17_wp76_img.spk`

# create keys
    . modular-tools.sh create_secureboot_signkey

create directory and keys as following:

pk8_key="keys/testkey.pk8"
x509_key="keys/testkey.x509.pem"

# secureboot update

run this:

    . modular-tools.sh sign_images_with_client_key

resulting image is at: 

signed/yocto.cwe

    . modular-tools.sh sign_images_with_client_key

# decrypt keys and read

    openssl x509 -in keys/testkey.x509.pem -noout -text
    
    openssl x509 -pubkey -noout -in keys/testkey.x509.pem  > keys/pubkey.pem


# Operational tasks

	# Configuring sim card instructions
    cm data apn wbdata
    cm data connect
