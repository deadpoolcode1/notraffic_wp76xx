# personal SWI
contains meta-layer for additions and modifications to the default Yocto build

# initial code pull

1. Accept legato licence online. See: https://docs.legato.io/latest/toolsGitHub.html

2. Install repo:
 

    mkdir ~/wp76xx_yocto3
    cd ~/wp76xx_yocto3
    curl https://storage.googleapis.com/git-repo-downloads/repo-1 > ~/bin/repo
    chmod a+x ~/bin/repo
    python3 ~/bin/repo init -u ssh://git@github.com/deadpoolcode1/notraffic_wp76xx_manifest -m mdm9x28/tags/SWI9X07Y_02.37.10.02/linux.xml -g default,-cache,proprietary ; repo sync
    git clone git@github.com:deadpoolcode1/notraffic_wp76xx.git -b yocto3 personal_swi
    cp personal_swi/modular-tools.sh .
    sudo git config --system --add safe.directory '*'

3. Install extra build tools


    sudo rm /bin/sh
    sudo ln -s /bin/bash /bin/sh
    sudo apt -y install chrpath gawk texinfo openjdk-8-jdk
    sudo apt -y cpp diffstat g++ gcc build-essential


# build image

    . modular-tools.sh yocto_build
    
    . modular-tools.sh sign_images_with_client_key
    
    . modular-tools.sh make_image_binary

# flash image to device

./fdt2.exe Release16_wp76_img.spk

notice to download fdt2 and required drivers from Sierra site

# flash image Linux

    sudo personal_swi/files//fwdwl-litehostx86_64 -f "./" -s Release16_wp76_img.spk  -d /dev/ttyUSB1 -p /dev/cdc-wdm1 -c QMI -m 4

Or:

    . modular-tools.sh flash_image_via_ssh



# accessing device

ssh root@192.168.2.2
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
    bitbake -c cleanstate openvpn
    bitbake -c compile openvpn

5. Build the yocto image again


# flash via ssh

    scp -oHostKeyAlgorithms=+ssh-rsa Release16_wp76_img.spk root@192.168.2.2:/tmp/
    ssh -oHostKeyAlgorithms=+ssh-rsa root@192.168.2.2 '/legato/systems/current/bin/fwupdate download /tmp/Release16_wp76_img.spk'

or use: `. modular-tools.sh flash_image_via_ssh`

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
