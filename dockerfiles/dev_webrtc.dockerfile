ARG FROM_IMAGE="ubuntu:22.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# store current user in USERNAME
ENV USERNAME=${USER:-root}


# switch to root user to install dependencies
USER root

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
    build-essential && \
    apt autoclean && apt autoremove && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

USER ${USERNAME}

########################################################################################################################
# SSH Setup
########################################################################################################################

USER root

# Install SSH server
RUN apt update && \
    apt install -y openssh-server

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

# Install conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniconda.sh && \
    ${CONDA_DIR}/bin/conda clean -afy

ENV CONDA_DIR=/opt/conda \
    PATH=$CONDA_DIR/bin:$PATH    

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda create -n env_isaaclab python=3.11

RUN conda init bash && \
    echo "export PATH=/opt/conda/bin:\$PATH" >> /home/${USERNAME}/.bashrc && \
    echo "conda activate env_isaaclab" >> /home/${USERNAME}/.bashrc

SHELL ["conda", "run", "-n", "env_isaaclab", "-v", "--no-capture-output", "/bin/bash", "-c"]

# Install Isaac Sim
RUN pip install "isaacsim[all,extscache]==5.1.0" --extra-index-url https://pypi.nvidia.com

RUN pip install -U torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128

# Agree to Isaac Sim EULA
ENV ACCEPT_EULA=Y


RUN git clone https://github.com/isaac-sim/IsaacLab.git /home/${USERNAME}/IsaacLab


ENV TERM xterm-256color
RUN cd /home/${USERNAME}/IsaacLab && \
    ./isaaclab.sh -i

SHELL ["/bin/sh", "-c"]



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