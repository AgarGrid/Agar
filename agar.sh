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
    gotToProjectRoot
    rm -rf $WORKSPACE_DIR
    checkWorkSpace
}

actionwatch(){ 
    log "Starting watch"
    startWatcherLoop
}

actionunwatch(){ 
    log "Starting unwatch"
    stopWatcherLoop
}
actionrestart(){ 
    log "Restart"
    startAll

}

actionstop(){ 
    log "Starting stop"
    stopAll
}


#############################################

startAll(){
    gotToWorkspaceRoot
    docker compose $(getBaseDockerCommand) up -d
}

stopAll(){
    gotToWorkspaceRoot
    docker compose $(getBaseDockerCommand) down
}

getBaseDockerCommand(){
    YML_LIST="$(getCoreYMLFiles) $(getNetworkYMLForHost) $(getConfigStorageYMLForHost) $(getFileStorageYMLForHost) $(getStackYMLForHost)"

    DOCKER_COMPOSE_COMMAND=""

    for yml in ${YML_LIST[@]}; do
       DOCKER_COMPOSE_COMMAND+=" -f $yml"
    done
    echo "${DOCKER_COMPOSE_COMMAND[@]}"
   
}

getCoreYMLFiles(){
    gotToWorkspaceRoot

    local CORE_STACK_LIST=()

    ### core compose
    for file in $CORE_COMPOSE_DIR/*.yml; do
        [ -f "$file" ] || continue
        CORE_STACK_LIST+=("$file")
        
    done

    ### core compose
    for file in $CORE_COMPOSE_DIR/storage/*.yml; do
        [ -f "$file" ] || continue
        CORE_STACK_LIST+=("$file")
        
    done



    echo "${CORE_STACK_LIST[@]}"

}

getStackYMLForHost(){

    HOST_STACK_YML=()
    HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"
    HOST_FILE_PATH="$HOST_DIR/$HOST_STACK_FILE"

    readarray -t HOST_STACK_LIST < $HOST_FILE_PATH
      
    for fileEntry in ${HOST_STACK_LIST[@]}; do
        HOST_YLM="$STACKS_DIR/$fileEntry.yml"
        HOST_STACK_YML+=("$HOST_YLM")
    done

    echo "${HOST_STACK_YML[@]}"
}

getConfigStorageYMLForHost(){

    HOST_STACK_YML=()
    HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"
    HOST_FILE_PATH="$HOST_DIR/$HOST_CONFIG_FILE"

    readarray -t HOST_STACK_LIST < $HOST_FILE_PATH
      
    for fileEntry in ${HOST_STACK_LIST[@]}; do
        HOST_YLM="$STACKS_CONFIG_DIR/$fileEntry.yml"
        HOST_STACK_YML+=("$HOST_YLM")
    done

    echo "${HOST_STACK_YML[@]}"
}

getFileStorageYMLForHost(){

    HOST_STACK_YML=()
    HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"
    HOST_FILE_PATH="$HOST_DIR/$HOST_STORAGE_FILE"

    readarray -t HOST_STACK_LIST < $HOST_FILE_PATH
      
    for fileEntry in ${HOST_STACK_LIST[@]}; do
        HOST_YLM="$STACKS_FILES_DIR/$fileEntry.yml"
        HOST_STACK_YML+=("$HOST_YLM")
    done

    echo "${HOST_STACK_YML[@]}"
}


getNetworkYMLForHost(){

    HOST_STACK_YML=()
    HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"
    HOST_FILE_PATH="$HOST_DIR/$HOST_NETWORK_FILE"

    readarray -t HOST_STACK_LIST < $HOST_FILE_PATH
      
    for fileEntry in ${HOST_STACK_LIST[@]}; do
        HOST_YLM="$STACKS_NETWORK_DIR/$fileEntry.yml"
        HOST_STACK_YML+=("$HOST_YLM")
    done

    echo "${HOST_STACK_YML[@]}"
}





stopWatcherLoop(){
    log "Stop Watcher Loop"
    gotToProjectRoot
    rm $WATCH_LOOP_FILE
}

startWatcherLoop(){
    log "Start Watcher Loop"
    gotToProjectRoot
    touch $WATCH_LOOP_FILE
    watcherLoop
}

watcherLoop(){
    gotToProjectRoot

    if [ "$(doesFileExists $WATCH_LOOP_FILE)" = true ] ; then
        log "Watcher Loop"
        gotToProjectRoot

        CHANGES=false



        if [ "$(remoteChanges $CORE_COMPOSE_DIR)" = true ] ; then
            log "CHANGES $CORE_COMPOSE_DIR"
            CHANGES=true
           # restartFromwatcher
        fi

        if [ "$(remoteChanges $STACKS_DIR)" = true ] ; then
            log "CHANGES $STACKS_DIR"
            CHANGES=true
           # restartFromwatcher
        fi

        HOST_DIR="./$HOST_DIR_PREFIX$(getHostName)"

        if [ "$(remoteChanges $HOST_DIR)" = true ] ; then
            log "CHANGES $HOST_DIR"
            CHANGES=true
           # restartFromwatcher
        fi
        


        if [ "$CHANGES" = true ]
        then  
            echo "Changes"
            restartFromwatcher
        else
            sleep $WATCHER_INTERVAL
            watcherLoop
        fi



        

    fi


  



    
}

restartFromwatcher(){
    actionunwatch
    actionstop
    actionrefresh
    actionrestart
    actionwatch
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
