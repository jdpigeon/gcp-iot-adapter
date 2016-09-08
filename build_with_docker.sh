#! /bin/bash

# simple script that builds the Pub/Sub adapter using the Elixir docker container

WORKSPACE=`pwd`
docker run --rm -i -t -v $WORKSPACE:/mnt/workspace \
        --name psadapter \
        elixir:1.2 \
        /bin/bash -c 'cd /mnt/workspace && ./build_adapter.sh'
