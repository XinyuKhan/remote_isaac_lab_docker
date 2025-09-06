#!/bin/bash

mkdir -p .downloads

cd .downloads

if [ -f "cuda-ubuntu2204.pin" ]; then
    echo "Files already downloaded."
else
    echo "Downloading files..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
fi

if [ -f "cuda-repo-ubuntu2204-12-8-local_12.8.0-570.86.10-1_amd64.deb" ]; then
    echo "Files already downloaded."
else
    echo "Downloading files..."
    wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-ubuntu2204-12-8-local_12.8.0-570.86.10-1_amd64.deb
fi

if [ -f "cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz" ]; then
    echo "Files already downloaded."
else
    echo "Downloading files..."
    wget https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz
fi

if [ -f "Miniconda3-latest-Linux-x86_64.sh" ]; then
    echo "Files already downloaded."
else
    echo "Downloading files..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
fi


if [ -f "pytorch.zip" ]; then
    echo "Directory already archived."
else
    echo "Downloading files..."
    if [ -d "pytorch" ]; then
        echo "Pytorch directory already exists."
    else
        echo "Cloning Pytorch repository..."
        git clone https://github.com/pytorch/pytorch -b v2.3.1 --recursive
    fi
    zip -r pytorch.zip pytorch
fi