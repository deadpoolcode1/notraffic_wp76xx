# personal SWI
contains meta-layer for additions and modifications to the default Yocto build

# initial code pull

curl https://storage.googleapis.com/git-repo-downloads/repo-1 > ~/bin/repo

chmod a+x ~/bin/repo

python3 ~/bin/repo init -u ssh://git@github.com/deadpoolcode1/notraffic_wp76xx_manifest -m mdm9x28/tags/SWI9X07Y_02.37.10.02/linux.xml -g default,-cache,proprietary ; repo sync


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



# accesing device

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

#modifying Yocto build

all YOcto related modifications are done under layer "personal_swi"

#overriding default openssl and openvpn

notice it's not a simple task since that have many dependancies, however I prepared the infrastructure for that

loog under personal_swi , for files: *.bbappend_option 

in case you will modify the extention to *.bbappend it will override existing recipies

notice to open the *.bbappend_option and setup per the needed version 

#flash via ssh

    scp -oHostKeyAlgorithms=+ssh-rsa Release16_wp76_img.spk root@192.168.2.2:/tmp/
    ssh -oHostKeyAlgorithms=+ssh-rsa root@192.168.2.2 '/legato/systems/current/bin/fwupdate download /tmp/Release16_wp76_img.spk'

or use: . modular-tools.sh flash_image_via_ssh 

#issues with initial build

some steps we did to resolve build issues:

sudo rm /bin/sh

sudo ln -s /bin/bash /bin/sh 

sudo apt-get install chrpath gawk texinfo

sudo apt-get install openjdk-8-jdk

git config --global --add safe.directory /home/notraffic-jig/dev/wpb/poky

git config --global --add safe.directory /home/notraffic-jig/dev/wpb/meta-openembedded

git config --global --add safe.directory /home/notraffic-jig/dev/wpb/meta-swi

git config --global --add safe.directory /home/notraffic-jig/dev/wpb/meta-swi-extras

git config --global --add safe.directory /home/notraffic-jig/dev/wpb/meta-swi-extras/common

#secureboot update

create directory and keys as following: 

pk8_key="keys/testkey.pk8"
x509_key="keys/testkey.x509.pem"

run this:

. modular-tools.sh sign_images_with_client_key

resulting image is at: 

signed/yocto.cwe

. modular-tools.sh sign_images_with_client_key
