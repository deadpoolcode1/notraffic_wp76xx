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

./fwdwl-litehostx86_64 -f "./" -s Release16_wp76_img.spk  -d /dev/ttyUSB1 -c QMI

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

