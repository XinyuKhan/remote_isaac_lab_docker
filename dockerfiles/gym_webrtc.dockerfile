ARG FROM_IMAGE="ubuntu:20.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# store current user in USERNAME
ENV USERNAME=${USER:-root}


# switch to root user to install dependencies
USER root

RUN --mount=type=bind,source=./compose/linux/gym/.downloads,target=/home/${USERNAME}/.downloads \
    cd /home/${USERNAME}/.downloads && \
    cp cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600 && \
    dpkg -i cuda-repo-ubuntu2204-12-8-local_12.8.0-570.86.10-1_amd64.deb && \
    cp /var/cuda-repo-ubuntu2204-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/ && \
    apt update && \
    apt install -y cuda-toolkit-12-8 && \
    apt clean && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# ENV PATH=/usr/local/cuda/bin:$PATH \
#     LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# RUN wget https://developer.download.nvidia.com/compute/cudnn/9.12.0/local_installers/cudnn-local-repo-debian12-9.12.0_1.0-1_amd64.deb && \
#     dpkg -i cudnn-local-repo-debian12-9.12.0_1.0-1_amd64.deb && \
#     sudo cp /var/cudnn-local-repo-debian12-9.12.0/cudnn-*-keyring.gpg /usr/share/keyrings/ && \
#     apt update && \
#     apt install -y cudnn && \
#     apt clean && rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/* && \
#     rm cudnn-local-repo-debian12-9.12.0_1.0-1_amd64.deb

RUN --mount=type=bind,source=./compose/linux/gym/.downloads,target=/home/${USERNAME}/.downloads \
    tar -xvf /home/${USERNAME}/.downloads/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz -C . && \
    cp cudnn-linux-x86_64-8.9.7.29_cuda12-archive/lib/libcudnn* /usr/lib/x86_64-linux-gnu/ && \
    cp -r cudnn-linux-x86_64-8.9.7.29_cuda12-archive/include/* /usr/include/x86_64-linux-gnu/ && \
    rm -rf cudnn-linux-x86_64-8.9.7.29_cuda12-archive


# Install Basic Dependencies
RUN apt update && DEBIAN_FRONTEND=noninteractive \
    apt upgrade -y && \
    apt install -y --no-install-recommends \
    locales \
    git \
    git-lfs \
    curl \
    wget \
    vim \
    sudo \
    software-properties-common \
    net-tools \
    htop \
    cmake \
    build-essential \
    openssh-server && \
    apt autoclean && apt autoremove && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*



USER ${USERNAME}

RUN echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH" >> /home/${USERNAME}/.bashrc && \
    echo "export PATH=/usr/local/cuda/bin:\$PATH" >> /home/${USERNAME}/.bashrc




########################################################################################################################
# SSH Setup
########################################################################################################################

USER root

# Configure SSH server
RUN echo 'X11Forwarding yes' >> /etc/ssh/sshd_config && \
    echo 'X11UseLocalhost no' >> /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#Port 22/Port 2220/' /etc/ssh/sshd_config

# Add SSHD entrypoint script
COPY ${RESOURCES_DIR}/sshd_entrypoint.sh /usr/local/bin/sshd_entrypoint.sh

RUN chown ${USERNAME}:${USERNAME} /usr/local/bin/sshd_entrypoint.sh && \
    chmod +x /usr/local/bin/sshd_entrypoint.sh && \
    mkdir -p /run/sshd && \
    echo "" >> /etc/supervisord.conf && \
    echo "# sshd entrypoint script" >> /etc/supervisord.conf && \
    echo "[program:sshd]" >> /etc/supervisord.conf && \
    echo "user=${USERNAME}" >> /etc/supervisord.conf && \
    echo "command=/usr/local/bin/sshd_entrypoint.sh" >> /etc/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisord.conf && \
    echo "startretries=3" >> /etc/supervisord.conf && \
    echo "stderr_logfile=/tmp/sshd.err.log" >> /etc/supervisord.conf && \
    echo "stdout_logfile=/tmp/sshd.out.log" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf
EXPOSE 2220


USER ${USERNAME}

# Set environment variables for Miniconda installation
ENV CONDA_DIR=/opt/conda \
    PATH=$CONDA_DIR/bin:$PATH

# Install dependencies and download/install Miniconda
RUN --mount=type=bind,source=./compose/linux/gym/.downloads,target=/home/${USERNAME}/.downloads \
    cd /home/${USERNAME}/.downloads && \
    cp Miniconda3-latest-Linux-x86_64.sh /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh && \
    $CONDA_DIR/bin/conda clean --all --yes
ENV CONDA_DIR=/opt/conda \
    PATH=$CONDA_DIR/bin:$PATH

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda create -n isaacgym python=3.8
RUN conda init bash && \
    echo "export PATH=/opt/conda/bin:\$PATH" >> /home/${USERNAME}/.bashrc && \
    echo "conda activate isaacgym" >> /home/${USERNAME}/.bashrc

SHELL ["conda", "run", "-n", "isaacgym", "-v", "--no-capture-output", "/bin/bash", "-c"]

RUN echo "export LD_LIBRARY_PATH=/opt/conda/envs/isaacgym/lib:\$LD_LIBRARY_PATH" >> /home/${USERNAME}/.bashrc


RUN pip install pyyaml typing_extensions numpy==1.23.5

COPY ${RESOURCES_DIR}/pytorch_50.patch /tmp/pytorch_50.patch

RUN --mount=type=bind,source=./compose/linux/gym/.downloads,target=/home/${USERNAME}/.downloads \
    unzip -q /home/${USERNAME}/.downloads/pytorch.zip -d . && \
    cd pytorch && \
    git apply /tmp/pytorch_50.patch && \
    export USE_CUDA=1 && \
    export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0" && \
    export MAX_JOBS=$(nproc) && \
    export PATH=/usr/local/cuda/bin:$PATH && \
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH && \
    python setup.py bdist_wheel && \
    cp dist/*.whl /home/${USERNAME}/ && \
    cd .. && rm -rf pytorch

RUN conda install -c conda-forge libstdcxx-ng=12 -y

RUN pip install torchvision==0.18.1 torchaudio==2.3.1 numpy==1.23.5


# restore shell
SHELL ["/bin/sh", "-c"]

# export USE_CUDA=1
# export USE_CUDNN=1
# export USE_NUMPY=1
# export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0"
# export MAX_JOBS=$(nproc)

# python setup.py bdist_wheel

# pyyaml typing_extensions 

# SHELL ["conda", "run", "-n", "isaacgym", "-v", "--no-capture-output", "/bin/bash", "-c"]

# RUN git clone https://github.com/pytorch/pytorch -b v2.3.1 --recursive
# conda install -c conda-forge gcc=12.1.0 -y
# conda install -c conda-forge libstdcxx-ng=12
# pip install torchvision==0.18.1 torchaudio==2.3.1 numpy==1.23.5

# wget https://developer.download.nvidia.com/compute/cudnn/9.12.0/local_installers/cudnn-local-repo-debian12-9.12.0_1.0-1_amd64.deb
# sudo dpkg -i cudnn-local-repo-debian12-9.12.0_1.0-1_amd64.deb
# sudo cp /var/cudnn-local-repo-debian12-9.12.0/cudnn-*-keyring.gpg /usr/share/keyrings/
# sudo apt-get update
# sudo apt-get -y install cudnn

########################################################################################################################
# Cleanup
########################################################################################################################


USER root
# Clear cache
RUN apt autoclean && apt autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pitch to avoid removing all content in ~/.cache
RUN sed -i "s|rm -rf /tmp/.X\* ~/.cache|rm -rf /tmp/.X\* ~/.cache/gstreamer\* ~/.cache/ksplash ~/.cache/nvidia ~/.cache/plasma\* ~/.cache/qt\* ~/.cache/ksycoca5\* ~/.cache/motd.legal-displayed|g" /etc/entrypoint.sh




# Restore User
USER ${USERNAME}