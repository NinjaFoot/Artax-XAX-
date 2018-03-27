#/bin/bash
NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
MAX=10

COINGITHUB=https://github.com/Artax-Project/Artax
COINPORT=21527
COINDAEMON=artaxd
COINCLI=artax-cli
COINTX=artax-tx
COINCORE=.artaxcore
COINCONFIG=artax.conf

checkForUbuntuVersion() {
   echo "[1/${MAX}] Checking Ubuntu version..."
    if [[ `cat /etc/issue.net`  == *16.04* ]]; then
        echo -e "${GREEN}* You are running `cat /etc/issue.net` . Setup will continue.${NONE}";
    else
        echo -e "${RED}* You are not running Ubuntu 16.04.X. You are running `cat /etc/issue.net` ${NONE}";
        echo && echo "Installation cancelled" && echo;
        exit;
    fi
}

updateAndUpgrade() {
    echo
    echo "[2/${MAX}] Runing update and upgrade. Please wait..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -y > /dev/null 2>&1
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1
    echo -e "${GREEN}* Done${NONE}";
}

setupSwap() {
    echo -e "${BOLD}"
    read -e -p "Add swap space? (Recommended for VPS that have 1GB of RAM) [Y/n] :" add_swap
    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        swap_size="4G"
    else
        echo && echo -e "${NONE}[3/${MAX}] Swap space not created."
        echo -e "${NONE}${GREEN}* Done${NONE}";
    fi

    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        echo && echo -e "${NONE}[3/${MAX}] Adding swap space...${YELLOW}"
        sudo fallocate -l $swap_size /swapfile
        sleep 2
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null 2>&1
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo -e "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Done${NONE}";
    fi
}

installFail2Ban() {
    echo
    echo -e "[4/${MAX}] Installing fail2ban. Please wait..."
    sudo apt-get -y install fail2ban > /dev/null 2>&1
    sudo systemctl enable fail2ban > /dev/null 2>&1
    sudo systemctl start fail2ban > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installFirewall() {
    echo
    echo -e "[5/${MAX}] Installing UFW. Please wait..."
    sudo apt-get -y install ufw > /dev/null 2>&1
    sudo ufw allow OpenSSH > /dev/null 2>&1
    sudo ufw allow $COINPORT/tcp > /dev/null 2>&1
    echo "y" | sudo ufw enable > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installDependencies() {
    echo
    echo -e "[6/${MAX}] Installing dependecies. Please wait..."

    sudo apt-get install git nano wget curl software-properties-common -qq -y > /dev/null 2>&1
    sudo add-apt-repository ppa:bitcoin/bitcoin -y > /dev/null 2>&1
    sudo apt-get update -qq -y > /dev/null 2>&1
    sudo apt-get install build-essential libtool autotools-dev pkg-config libssl-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libboost-all-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libevent-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libminiupnpc-dev -qq -y > /dev/null 2>&1
    sudo apt-get install autoconf -qq -y > /dev/null 2>&1
    sudo apt-get install automake -qq -y > /dev/null 2>&1
    sudo apt-get install libdb4.8-dev libdb4.8++-dev -qq -y > /dev/null 2>&1

    echo -e "${NONE}${GREEN}* Done${NONE}";
}

compileWallet() {
    echo
    echo -e "[7/${MAX}] Compiling wallet. Please wait, this might take a while to complete..."
    cd && mkdir new && cd new
    git clone $COINGITHUB coinsource  > /dev/null 2>&1
    cd coinsource
    sudo chmod 755 autogen.sh > /dev/null 2>&1
    sudo ./autogen.sh > /dev/null 2>&1
    sudo ./configure > /dev/null 2>&1
    sudo chmod 755 share/genbuild.sh > /dev/null 2>&1
    sudo make > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installWallet() {
    echo
    echo -e "[8/${MAX}] Installing wallet. Please wait..."
    cd src
    strip $COINDAEMON
    strip $COINCLI
    strip $COINTX
    sudo mv $COINDAEMON /usr/bin
    sudo mv $COINCLI /usr/bin
    sudo mv $COINTX /usr/bin
    cd && sudo rm -rf new
    cd
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

configureWallet() {
    echo
    echo -e "[9/${MAX}] Configuring wallet. Please wait..."
    $COINDAEMON -daemon > /dev/null 2>&1
    sleep 5
    $COINCLI stop > /dev/null 2>&1
    sleep 5

    mnip=$(curl --silent ipinfo.io/ip)
    rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rpcpass=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`

    echo -e "rpcuser=${rpcuser}\nrpcpassword=${rpcpass}\nrpcallowedip=127.0.0.1" > ~/$COINCORE/$COINCONFIG

    $COINDAEMON -daemon > /dev/null 2>&1
    sleep 5

    mnkey=$($COINCLI masternode genkey)

    $COINCLI stop > /dev/null 2>&1
    sleep 5

    echo -e "rpcuser=${rpcuser}\nrpcpassword=${rpcpass}\nrpcallowedip=127.0.0.1\nmasternode=1\nbind=${mnip}:${COINPORT}\nmasternodeprivkey=${mnkey}\naddnode=159.203.161.244 \naddnode=104.131.44.238 \naddnode=178.62.57.88 \naddnode=159.65.94.40\naddnode=202.91.33.100:21507\naddnode=202.91.33.100:21510\naddnode=18.216.12.22:21527\naddnode=90.156.157.28:21526\naddnode=137.74.173.114:21529\naddnode=18.219.213.124:21527\naddnode=167.99.164.67:21527\naddnode=185.125.217.171:21527\naddnode=167.99.7.215:21527\naddnode=144.202.14.178:21527\naddnode=45.32.186.141:21530\naddnode=121.63.252.178:21520\naddnode=45.76.196.74:21527\naddnode=90.156.157.28:21528\naddnode=202.91.33.100:21503\naddnode=137.74.173.114:21528\naddnode=121.63.252.178:21514\naddnode=165.227.24.233:21527\naddnode=54.37.72.144:21528\naddnode=67.205.165.150:21527" > ~/$COINCORE/$COINCONFIG

    echo -e "${NONE}${GREEN}* Done${NONE}";
}

startWallet() {
    echo
    echo -e "[10/${MAX}] Starting wallet daemon..."
    $COINDAEMON -daemon > /dev/null 2>&1
    sleep 2
    echo -e "${GREEN}* Done${NONE}";
}

clear
cd

echo && echo

echo -e ${YELLOW}
echo -e "${YELLOW}**********************************************************************${NONE}"
echo -e "${YELLOW}**********************************************************************${NONE}"
echo -e "${YELLOW}****************************    **************************************${NONE}"
echo -e "${YELLOW}****************************     *************************************${NONE}"
echo -e "${YELLOW}************************** **     ************************************${NONE}"
echo -e "${YELLOW}*************************   *     ************************************${NONE}"
echo -e "${YELLOW}*************************   ***    ***********************************${NONE}"
echo -e "${YELLOW}************************     **     **********************************${NONE}"
echo -e "${YELLOW}************************    ***      *********************************${NONE}"
echo -e "${YELLOW}***********************     ****     *********************************${NONE}"
echo -e "${YELLOW}***********************    *****      ********************************${NONE}"
echo -e "${YELLOW}**********************     ******      *******************************${NONE}"
echo -e "${YELLOW}**********************    ********     *******************************${NONE}"
echo -e "${YELLOW}*********************     *********    *******************************${NONE}"
echo -e "${YELLOW}*********************    ***********     *****************************${NONE}"
echo -e "${YELLOW}*************************************    *****************************${NONE}"
echo -e "${YELLOW}*************                             ****************************${NONE}"
echo -e "${YELLOW}**********                                 ***************************${NONE}"
echo -e "${YELLOW}*******                                    ***************************${NONE}"
echo -e "${YELLOW}******       *                              **************************${NONE}"
echo -e "${YELLOW}******      ******      **********************************************${NONE}"
echo -e "${YELLOW}*****      ******      ***********************************************${NONE}"
echo -e "${YELLOW}*****      ******     ************************************************${NONE}"
echo -e "${YELLOW}******       ***     *************************************************${NONE}"
echo -e "${YELLOW}*******       **     *                          **********************${NONE}"
echo -e "${YELLOW}*********     *     **                           *********************${NONE}"
echo -e "${YELLOW}*********    *      *                            *********************${NONE}"
echo -e "${YELLOW}**************     **                             ********************${NONE}"
echo -e "${YELLOW}**************     ***************************************************${NONE}"
echo -e "${YELLOW}*************     ****************************************************${NONE}"
echo -e "${YELLOW}************      ****************************************************${NONE}"
echo -e "${YELLOW}************     *****************************************************${NONE}"
echo -e "${YELLOW}**********************************************************************${NONE}"
echo -e "${YELLOW}**********************************************************************${NONE}"
echo -e "${YELLOW}**********************************************************************${NONE}"
echo -e "${YELLOW}*                                                                    *${NONE}"
echo -e "${YELLOW}*    ${NONE}${BOLD}This script will install and configure your Artax masternode.${NONE}${YELLOW}   *${NONE}"
echo -e "${YELLOW}*                                                                    *${NONE}"
echo -e "${YELLOW}**********************************************************************${NONE}"
echo && echo

echo -e "${BOLD}"
read -p "This script will setup your Artax Masternode. Do you wish to continue? (y/n)?" response
echo -e "${NONE}"

if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    checkForUbuntuVersion
    updateAndUpgrade
    setupSwap
    installFail2Ban
    installFirewall
    installDependencies
    compileWallet
    installWallet
    configureWallet
    startWallet

    echo && echo -e "${BOLD}The VPS side of your masternode has been installed. Save the following line so you can use it to complete your local wallet part of the setup${NONE}".
    echo && echo -e "${BOLD}masternode1 ${mnip}:${COINPORT} ${mnkey} <txid for 2500 XAX> <output index for 2500 XAX>${NONE}"
    echo && echo -e "${BOLD}Monitor synchronization status until ‘\"blocks\": <current block num>’ is synchronized with explorer
${COINCLI} getinfo${NONE}" && echo
else
    echo && echo "Installation cancelled" && echo
fi
