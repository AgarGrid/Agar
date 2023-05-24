#!/bin/bash

initialise(){   
    
    checkWorkSpace

    ## Check of param is passed already
    if [ ! -z "$1" ]
    then
        echo " With param $1"
        doAction $1
    else
        echo "No With param"
        askOption
    fi


    ##refreshHostsConfig
    






    
    ##checkWorkSpace



    ##checkForRemoteChanges
}

askOption(){
    echo "Select option"
    echo "	1 -	refresh workspace (./agar refresh)"
    echo "	2 -	start watcher  (./agar watch)"
    echo "	3 -	Stop watcher  (./agar unwatch)"
    echo "	4 -	restart services (./agar restart)"
    echo "	5 -	stop services (./agar stop)"
    echo "OR"
    echo "	q -	To quit"

    read -p 'Type option: ' option
    actionOption $option
    
}

actionOption(){
    
    if [[ "$1" == "1" ]]; then
      restartSCript "refresh"
    elif [[ "$1" == "2" ]]; then
        restartSCript "watch" 
    elif [[ "$1" == "3" ]]; then
        restartSCript "unwatch"
    elif [[ "$1" == "4" ]]; then
        restartSCript "restart"
    elif [[ "$1" == "5" ]]; then
        restartSCript "stop" 
    else
        exit
    fi
}

restartSCript(){
    ScriptLoc=$(readlink -f "$0")
    exec "$ScriptLoc" $1

}



doAction(){
    if [[ "$1" == "refresh" ]]; then
      actionrefresh
    elif [[ "$1" == "watch" ]]; then
        actionwatch 
    elif [[ "$1" == "unwatch" ]]; then
        actionunwatch 
    elif [[ "$1" == "restart" ]]; then
        actionrestart 
    elif [[ "$1" == "stop" ]]; then
        actionstop 
    else
        exit
    fi
    

}


actionrefresh(){ 
    log "Starting refresh" 
    rm -rf $WORKSPACE_DIR
    checkWorkSpace
}

actionwatch(){ 
    log "Starting watch"
}

actionunwatch(){ 
    log "Starting unwatch"
}
actionrestart(){ 
    log "Restart"
    startAll

}

actionstop(){ 
    log "Starting stop"
}










#############################################

startAll(){
    gotToWorkspaceRoot
    YML_LIST="$(getCoreYMLFiles) $(getStackYMLForHost)"

    DOCKER_COMPOSE_COMMAND=""

    for yml in ${YML_LIST[@]}; do
       log "Starting $yml"
       DOCKER_COMPOSE_COMMAND+=" -f $yml"
    done
    DOCKER_COMPOSE_COMMAND+=" up -d"

    echo $DOCKER_COMPOSE_COMMAND


}

getCoreYMLFiles(){
    gotToWorkspaceRoot

    local CORE_STACK_LIST=()

    ### core compose
    for file in $CORE_COMPOSE_DIR/*.yml; do
        [ -f "$file" ] || continue
        CORE_STACK_LIST+=("$file")
        
    done

    echo "${CORE_STACK_LIST[@]}"

}

getStackYMLForHost(){

    HOST_STACK_YML=()
    HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"
    HOST_STACK_FILE="$HOST_DIR/$HOST_STACK_FILE"

    readarray -t HOST_STACK_LIST < $HOST_STACK_FILE
      
    for fileEntry in ${HOST_STACK_LIST[@]}; do
        HOST_YLM="$HOST_DIR/$fileEntry.yml"
        HOST_STACK_YML+=("$HOST_YLM")
    done

    echo "${HOST_STACK_YML[@]}"
}



watcherLoop(){
    log "Watcher Loop"
    sleep $WATCHER_INTERVAL

    if [ "$(remoteChanges $CORE_COMPOSE_DIR)" = true ] ; then
        echo "CHANGES"
      
    else 
        echo "NO CHANGES"
    fi


    watcherLoop
}

remoteChanges(){
    gotToWorkspaceRoot
    cd $1
    git fetch

    LOCAL_REV=$(git rev-parse HEAD)
    REMOTE_REV=$(git rev-parse @{u})

    if [ "$LOCAL_REV" == "$REMOTE_REV" ]; then
       echo "false" 
    else
        echo "true" 
    fi
}

checkWorkSpace(){
    gotToProjectRoot
    if [ "$(workspaceExists)" = false ] ; then
        remakeFolder $WORKSPACE_DIR
        log "no workspace"

        refreshWorkSpaceElement $STACKS_DIR $STACKS_REPO
        refreshWorkSpaceElement $CORE_COMPOSE_DIR $CORE_COMPOSE_REPO
        refreshHostsConfig
    fi
}

refreshHostsConfig(){
    HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"
    HOST_REPO="$GIT_HUB_ROOT_URL$HOST_DIR_PREFIX$(getHostName)"
    refreshWorkSpaceElement $HOST_DIR $HOST_REPO
}



refreshWorkSpaceElement(){
    log "refreshing WorkSpaceElement - $1"
    gotToWorkspaceRoot
    remakeFolder $1
    git clone $2 $1
}










## --------------------------------------------

gotToProjectRoot(){
    cd $PROJECT_ROOT_LOCATION
}

setWorkingDirToScriptLocation(){
    cd "$(dirname "$0")"
    PROJECT_ROOT_LOCATION=$(pwd)
}

importCoreShellScripts(){
    if [ ! -d "$BASHCORE_DIR" ]
    then
        git clone https://github.com/AgarGrid/bashcore
    fi
    includeBashCoreSripts
}

includeBashCoreSripts() {
    for f in $BASHCORE_DIR/* $BASHCORE_DIR/**/* ; do
        if [ ! -d "$f" ]
        then
            source $f
        fi
    done;
}

## --- Startup ---
PROJECT_ROOT_LOCATION=""
setWorkingDirToScriptLocation

## App specific config
source ./general.conf
importCoreShellScripts

log "-------------------------- STARTING $(currentScriptName) --------------------------"
initialise $@
