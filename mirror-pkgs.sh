#!/bin/bash

# Usage: ./mirror-pkgs.sh configurationFile [make] [packageListFile]
#
# E.g.: ./mirror-pkgs.sh mirror-pkgs.conf
#       ./mirror-pkgs.sh mirror-pkgs.conf make pakcagesList.lst
#
# If no packages list file was provided, scipt will look for file
# mirror-pkgs.lst in $workTree
# 
# This script needs packages list file 'mirror-pkgs.lst' in $workTree
# mirrors list should caintain full url to git repo
# or module name (with vendor prefix).
# If the moudle is registered in packagis.org the repoository url
# will be fetched automaticaly
#
# e.g. mirrors.lst file:
#
# https://github.com/phly/PhlyRestfully.git
# zendframework/zendframework
# phpunit/dbunit
# 

if [ $# -eq 0 ] || [ ! -f $1 ]; then
    echo -e "Invalid or none configuration file provided, check sample mirrors.conf-dist file\n"
    echo -e "Usage: $0 configurationFile [make] [packageListFile]\n"
    echo -e "E.g.: $0 mirror-pkgs.conf"
    echo -e "      $0 mirror-pkgs.conf make packagesList.lst\n"
    exit 1
fi
source $1

packagistUrl='https://packagist.org/packages'
satisPath=public
satisConfigPath=$workTree$satisPath
satisConfigFile=$satisConfigPath'/satis.json'
packagesListFile='mirror-pkgs.lst'

function makeComposer {
    composerUrl='https://getcomposer.org/installer'
    composerBin=`which composer 2> /dev/null`
    if [ -z $composerBin ]; then
        cd $satisConfigPath
        composerBin='composer.phar'
        if [ ! -e $composerBin ];then
            curl -sS $composerUrl | php
        fi
    fi
}

function makeSatis {
    satisBin='satis/bin/satis'
    if [ ! -e $satisBin ]; then
      php $composerBin create-project composer/satis --stability=dev --keep-vcs
    fi
    php $satisBin build $satisConfigFile .
}

function refreshMirrors {
    find . -mindepth 1 -maxdepth 1 -type d -name "*.git" \( ! -iname ".*" \) -exec git -p --git-dir="{}" fetch \;
}

function makeMirrors {
    echo -e $packagesHeader > $satisConfigFile

    if [ $# -gt 0 ] && [ -n "$1" ]; then
        packagesListFile=$1
    fi

    for repoUrl in `cat $packagesListFile | sed '/^\s*#/d;/^\s*$/d'`
    do
        if [[ $repoUrl != http* ]]; then
            repoUrl=`curl -s $packagistUrl/$repoUrl | grep Canonical | sed -r -e 's|.*?href="||' -e 's|".*||' | -e 's#http://github.com#https://github.com#'`
        fi
        echo "Adding repository $repoUrl"
        repoFolder=`echo $repoUrl | sed -r "s#^http(.+?)//[a-z.]+?/##"`

        if [[ $repoFolder != *.git ]]; then
            repoFolder=${repoFolder}.git
        fi

        if [ ! -d $workTree/$repoFolder ]; then
            mkdir -p $workTree/$repoFolder
            cd $workTree/$repoFolder
            echo -e "Clonning $repoUrl"
            `git clone --bare $repoUrl .`
        fi

        echo -e "{ \"type\": \"vcs\", \"url\": \"$packagesUrl$repoFolder\" }," >> $satisConfigFile
    done
    sed -i '$s/,$//' $satisConfigFile
    echo -e $packagesFooter >> $satisConfigFile
}

if [ ! -e $satisConfigPath ];then mkdir $satisConfigPath; fi

if [ $# -ge 2 ] && [ $2 == 'make' ]; then
    cd $workTree
    makeMirrors $3
fi

refreshMirrors

cd $workTree$satisPath
makeComposer
makeSatis
