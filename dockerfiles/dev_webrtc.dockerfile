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

RUN git clone https://github.com/isaac-sim/IsaacSim.git /home/${USERNAME}/IsaacSim-src && \
    cd /home/${USERNAME}/IsaacSim-src && \
    git checkout v5.0.0 && \
    git lfs install && \
    git lfs pull && \
    touch .eula_accepted && \
    ./build.sh && \
    ln -s _build/linux-x86_64/release /home/${USERNAME}/IsaacSim

RUN git clone -b feature/isaacsim_5_0 https://github.com/isaac-sim/IsaacLab.git /home/${USERNAME}/IsaacLab && \
    cd /home/${USERNAME}/IsaacLab && \
    ln -s ../IsaacSim _isaac_sim

ENV TERM xterm-256color    
RUN cd /home/${USERNAME}/IsaacLab && \
    ./isaaclab.sh -i

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