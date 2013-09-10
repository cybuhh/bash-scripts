#!/bin/bash


if [ ! -f $1 ]; then
  echo "Invalid or none configuration file provided, check sample mirrors.conf-dist file"
  exit
fi
source $1

packagistUrl='https://packagist.org/packages'
satisPath=public
satisConfigPath=$workTree$satisPath
satisConfigFile=$satisConfigPath'/satis.json'

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

  for repoUrl in `cat mirrors.lst | sed '/^\s*#/d;/^\s*$/d'`
  do
    echo $repoUrl
    if [[ $repoUrl != http* ]]; then
		repoUrl=`curl -s $packagistUrl/$repoUrl | grep Canonical | sed -r -e 's|.*?href="||' -e 's|".*||'`
    fi
    echo $repoUrl
    echo "basename $repoUrl"
    repoFolder=`basename $repoUrl`
    if [[ $repoFolder != *.git ]]; then
		repoFolder=${repoFolder}.git
    fi
    if [ ! -d $repoFolder ]; then
      echo -e "Clonning $repoUrl"
      `git clone --bare $repoUrl`
    fi

    echo -e "{ \"type\": \"vcs\", \"url\": \"$packagesUrl$repoFolder\" }," >> $satisConfigFile
  done
  sed -i '$s/,$//' $satisConfigFile
  echo -e $packagesFooter >> $satisConfigFile
}

if [ ! -e $satisConfigPath ];then mkdir $satisConfigPath; fi

if [ $2 == 'make' ]; then
    cd $workTree
    makeMirror
fi

cd $workTree$satisPath
makeComposer
makeSatis
