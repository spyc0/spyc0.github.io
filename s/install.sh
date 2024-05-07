#!/bin/bash

echo "alias cl='clear;reset'" >> ~/.bashrc
source ~/.bashrc

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -f -y vlc
sudo apt-get install -f -y chromium-browser
sudo apt-get install -f -y yt-dlp
