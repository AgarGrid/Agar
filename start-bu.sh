#!/bin/bash


initialise(){     
    clear
    PARAM=$1
    ARG=$2

    if [[ "$PARAM" == "setup" ]]; then
        TARGET_BRANCH=$ARG
        setupWorkSpaceRepos $TARGET_BRANCH
        setupWorkSpaceFile
    elif [[ "$PARAM" == "devmode" ]]; then
        reloadWorkspaceFile
        setReposToDevelopmentMode     
    elif [[ "$PARAM" == "releasemode" ]]; then
        reloadWorkspaceFile
        setReposToReleaseMode
    elif [[ "$PARAM" == "build" ]]; then
        reloadWorkspaceFile
        buildAllPlatforms
    elif [[ "$PARAM" == "quiet" ]]; then
        reloadWorkspaceFile
        echo "No more warnings or y/n confirms will be given - you have been warned!"
        setQuietFlag "true"
    elif [[ "$PARAM" == "noisy" ]]; then
        reloadWorkspaceFile
        setQuietFlag ""
    elif [[ "$PARAM" == "clean" ]]; then
        cleanAllFiles
    elif [[ "$PARAM" == "haxlibdev" ]]; then
        setHaxelibToLocal
    elif [[ "$PARAM" == "haxlibgit" ]]; then
        setHaxelibGit
    else
        outputHelp
    fi
}

outputHelp(){
    echo ""
    echo "./workSpace.sh [PARAM]"
    echo ""
    echo "      ./workSpace.sh setup        - pull and setup new workspace folder"
    echo "      ./workSpace.sh clean        - Will DELETE workspace and output folders"
    echo "      ./workSpace.sh devmode      - Set workspace to develop mode"
    echo "      ./workSpace.sh releasemode  - Set workspace to release mode"
    echo "      ./workSpace.sh build        - builds all"
    echo "      ./workSpace.sh quiet        - sets a flag to surpress y/n confirm - good for CICD builds"
    echo "      ./workSpace.sh noisy        - sets a flag to allow y/n confirm - this is default"
    echo "      ./workSpace.sh haxlibdev    - Sets haxelib to use local workspace libraries"
    echo "      ./workSpace.sh haxlibgit    - Sets haxelib to use Git master libraries"
}

cleanAllFiles(){
    checkProceed "WARNING - This will PERMANENTLY delete the workspace and out folders - you will have to run setup again - all local work will be lost "
    rm -rf $OUT_DIR
    rm -rf $WORKSPACE_DIR
}

setQuietFlag(){
    setVariableWorkSpaceFile "QUIET_MODE" $1
}

setReposToDevelopmentMode(){
    checkProceed "Setting to Develop mode\nThis will change all repo branches to $DEV_BRANCH and setup local haxelibs"
    setAllReposToBranch $DEV_BRANCH
    setVariableWorkSpaceFile "REPO_MODE" "develop"
}

setReposToReleaseMode(){
    checkProceed "Setting to Release mode\nThis will change all repo branches to $RELEASE_BRANCH and setup remote haxelibs"
    setAllReposToBranch $RELEASE_BRANCH
    setVariableWorkSpaceFile "REPO_MODE" "release"
}

setAllReposToBranch(){
    TARGET_BRANCH=$1
    cd $WORKSPACE_DIR
    FULL_PATH_WORKSPACE_DIR="$(pwd)"

    for d in */ ; do
        [ -L "${d%/}" ] && continue        
        REPO_PATH="$FULL_PATH_WORKSPACE_DIR/$d"

        setBranch $REPO_PATH $TARGET_BRANCH
    done
}

setupWorkSpaceRepos(){

    TARGET_BRANCH=$1
    if [ -d "$WORKSPACE_DIR" ] 
    then
        checkProceed "WARNING - Work Space already setup\nIf you proceed it WILL Delete all local changes and pull fresh repos"
    fi

    remakeFolder $WORKSPACE_DIR

    cleanPullRepoGroup $LIB_DIR "${ALL_HS_HAXELIB_REPO[@]}"
    cleanPullRepoGroup $PLATFORM_DIR "${ALL_PLATFORM_REPO[@]}"
    cleanPullRepoGroup $RELEASE_IMG_DIR "${ALL_RELEASE_IMG_REPO[@]}"
    cleanPullRepoGroup $DEV_DB_DIR "${ALL_DEV_DB_REPO[@]}"

    pullReleaseRepo $WORKSPACE_DIR $RELEASE_REPO
}

pullReleaseRepo(){
    gotToProjectRoot
    pullRepo $1 $2 
}

cleanPullRepoGroup(){

    TARGET_DIR=$1
    shift
    ALL_REPOS=("$@")

    gotToProjectRoot
    remakeFolder $TARGET_DIR

    for REPO in "${ALL_REPOS[@]}"
    do
        gotToProjectRoot
        pullRepo $TARGET_DIR $REPO 
    done
}

checkProceed(){
    echo -e $1

    echo $QUIET_MODE

    if [[ "$QUIET_MODE" == "true" ]]; then
        echo "In quiet mode - proceeding"
         
    else
         while true; do

        read -p "Do you want to proceed? (y/n) " yn

        case $yn in 
            [yY] ) echo ok, we will proceed;
                break;;
            [nN] ) echo exiting...;
                exit;;
            * ) echo invalid response;;
        esac

        done
    fi   
}

pullRepo(){
    TARGET_DIR=$1 
    REPO=$2
    echo "Cloning - $REPO"
    cd $TARGET_DIR
    git clone $REPO
}

setBranch(){
    REPO_FOLDER=$1
    TARGET_BRANCH=$2

    cd $REPO_FOLDER
    git checkout $TARGET_BRANCH
}

setupWorkSpaceFile(){
    gotToProjectRoot

    PATH_TO_WORKSPACE_FILE="$WORKSPACE_DIR/$WORKSPACE_FILE_NAME"

    touch $PATH_TO_WORKSPACE_FILE
    
    for WORKSPACE_FILE_VAR in "${WORKSPACE_FILE_VARS[@]}"
    do
        BLANK_VAR="$WORKSPACE_FILE_VAR=\"\""
        echo $BLANK_VAR >> $PATH_TO_WORKSPACE_FILE
    done
}

setVariableWorkSpaceFile () {

    gotToProjectRoot

    VARIABLE="${1}"
    CONTENT="${2}"
    PATH_TO_WORKSPACE_FILE="$WORKSPACE_DIR/$WORKSPACE_FILE_NAME"

    if [ ! -f "${PATH_TO_WORKSPACE_FILE}" ]; then
        showErrorSetupFirstAndExit
    fi

    sed -i "s/^${VARIABLE}\=.*/${VARIABLE}=\"${CONTENT}\"/" "${PATH_TO_WORKSPACE_FILE}"

    reloadWorkspaceFile
}

reloadWorkspaceFile(){
    PATH_TO_WORKSPACE_FILE="$WORKSPACE_DIR/$WORKSPACE_FILE_NAME"

    if [ ! -f "${PATH_TO_WORKSPACE_FILE}" ]; then
        showErrorSetupFirstAndExit
    fi

    source $PATH_TO_WORKSPACE_FILE
}

showErrorSetupFirstAndExit(){
    clear
    echo "No Workspace setup!, you should do that first"
    outputHelp
    exit
}

setHaxelibToLocal(){
    for HS_HAXELIB in "${ALL_HS_HAXELIB[@]}"
    do
        HAXELIB_LOCAL_PATH="$WORKSPACE_DIR/$HS_HAXELIB"
        haxelib dev $HS_HAXELIB $HAXELIB_LOCAL_PATH
    done
}

setHaxelibGit(){

    for HS_HAXELIB in "${ALL_HS_HAXELIB[@]}"
    do
        HAXELIB_LOCAL_PATH="$WORKSPACE_DIR/$HS_HAXELIB"

        haxelib dev $HS_HAXELIB
        haxelib update $HS_HAXELIB
    done
}

buildAllPlatforms(){
    checkProceed "Building all platforms\nThis will wipe previouse builds"
   
    SOURCE_ROOT=$WORKSPACE_DIR
    remakeFolder $OUT_DIR

    for PLATFORM in "${ALL_PLATFORMS[@]}"
   do
       buildPlatform $PLATFORM $SOURCE_ROOT
    done
}


buildPlatform(){
    SOURCE_ROOT=$2
    TARGET_DIR="$OUT_DIR/$1"
    SOURCE_DIR="$SOURCE_ROOT/$1"
    PLATFORM_NAME=$1
    HXML_FILE="build.hxml"

    setupPlatformTargetDir $TARGET_DIR
    copyAssets $SOURCE_DIR $TARGET_DIR
    runHaxeBuild $HXML_FILE $SOURCE_DIR
    moveHaxeBuildOutput $SOURCE_DIR $TARGET_DIR
}

copyAssets(){
    gotToProjectRoot
    ASSET_SOURCE_DIR="$1/assets"
    ASSET_TARGET_DIR="$2/assets"
    cp -a $ASSET_SOURCE_DIR $ASSET_TARGET_DIR
}

moveHaxeBuildOutput(){
    gotToProjectRoot
    OUT_SOURCE_DIR="$1/out"
    OUT_TARGET_DIR="$2"
    cp -a "$OUT_SOURCE_DIR/." $OUT_TARGET_DIR
}

setupPlatformTargetDir(){
    remakeFolder $1
}

runHaxeBuild(){
    HXML_FILE=$1
    SOURCE_DIR=$2
    cd $SOURCE_DIR
    haxe $HXML_FILE
}

remakeFolder(){
    rm -rf $1
    mkdir $1
}


## --------------------------------------------

gotToProjectRoot(){
    cd $PROJECT_ROOT_LOCATION
}

setWorkingDirToScriptLocation(){
    cd "$(dirname "$0")"
    PROJECT_ROOT_LOCATION=$(pwd)
}

## --- Startup ---
PROJECT_ROOT_LOCATION=""
setWorkingDirToScriptLocation
source ./build.config
initialise $@
