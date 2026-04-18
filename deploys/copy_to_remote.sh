#!/bin/bash

# chmod +x ./copy_to_remote.sh
# ./copy_to_remote.sh remote_user remote_host local_release_dir release_name remote_release_dir

echo "Started"

echo "ssh $1@$2"
echo "remote release directory: $5/$4"
echo "ssh $1@$2 mkdir -p $5/$4"

ssh "$1@$2" "mkdir -p $5/$4"

echo "remote release directory was made: $5/$4"

echo "started scp /$3/$4/app.tar.gz $1@$2:$5/$4"

scp "/$3/$4/app.tar.gz" "$1@$2:$5/$4"

echo "finished scp /$3/$4/app.tar.gz $1@$2:$5/$4"

echo "ssh $1@$2 tar -xvf $5/$4/app.tar.gz"

ssh "$1@$2" "tar -xf $5/$4/app.tar.gz -C $5/$4"


# ssh "$1@$2" "tar -xvf $5/$4/app.tar.gz"


echo "Finished"