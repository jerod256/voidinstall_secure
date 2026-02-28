#!/bin/bash

xbps-install -uy xbps
xbps-install -Sy vim git parted

mkdir /install
cd /install
git clone https://github.com/jerod256/voidinstall_secure.git
