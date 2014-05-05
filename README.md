bash-scripts
============
mirror-pkgs - sample hooks/post-receive

#!/bin/bash

workTree=/git/mirror-pkgs
listFile=mirror-pkgs.lst
cd $workTree && git show HEAD:$listFile > $listFile

/home/matcybur/bash-scripts/mirror-pkgs.sh /home/matcybur/bash-scripts/mirror-pkgs.conf make $workTree/$listFile

rm $workTree/$listFile