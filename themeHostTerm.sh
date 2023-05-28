#!/bin/bash


#### Just a helper script that i add the the .zshrc that will colour the termainal and print some info, so i know where i am working####

initialise(){ 
    clear
    HOST_NAME=`echo $(uname -n) | tr '[a-z]' '[A-Z]'`
    HOST_THEME_VAR_NAME="$HOST_NAME$HOST_THEME_SUFFIX"
    HOST_THEME="${!HOST_THEME_VAR_NAME}"

    if [ ! -z "${HOST_THEME}" ]; then
        ##echo "Found HOST_THEME - $HOST_THEME"
        ## set theme
        printf %b "\e]11;$HOST_THEME\a"
        figlet $HOST_NAME
        neofetch --off --color_blocks off --disable icons resolution de wm theme terminal kernal
    fi
}


setWorkingDirToScriptLocation(){
    echo "----- setWorkingDir -----"
    echo "Current dir -->"$(pwd)
    cd "$(dirname "$0")"
    echo "Working Dir Set to -->"$(pwd)
}


## --- Startup ---
setWorkingDirToScriptLocation
##importCoreShellScripts
source ./general.conf
initialise $1