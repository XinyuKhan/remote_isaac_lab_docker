ARG FROM_IMAGE="ubuntu:22.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# cuRobo CUDA variant: cu12-torch (default) or cu13-torch
# Override with: --build-arg CUROBO_CUDA_VARIANT=cu13-torch
ARG CUROBO_CUDA_VARIANT="cu12-torch"

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
    build-essential \
    openssh-server && \
    apt autoclean -y && apt autoremove -y && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

USER ${USERNAME}

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


########################################################################################################################
# cuRobo Installation
# Reference: https://nvlabs.github.io/curobo/latest/getting-started/installation.html
########################################################################################################################

USER root

# Install uv (recommended by cuRobo)
ENV UV_INSTALL_DIR=/usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=${UV_INSTALL_DIR} sh && \
    chmod +x ${UV_INSTALL_DIR}/uv ${UV_INSTALL_DIR}/uvx

USER ${USERNAME}

ENV CUROBO_DIR=/home/${USERNAME}/curobo \
    CUROBO_VENV=/home/${USERNAME}/curobo/.venv

# Clone cuRobo
RUN git clone https://github.com/NVlabs/curobo ${CUROBO_DIR} --branch v0.8.0

# Create virtual environment with Python 3.11 and install cuRobo with CUDA 12.x torch support
ENV TERM=xterm-256color
RUN cd ${CUROBO_DIR} && \
    uv venv --python 3.12 && \
    . ${CUROBO_VENV}/bin/activate && \
    uv pip install ".[${CUROBO_CUDA_VARIANT}]"

ENV SOMA_RETARGETER_DIR=/home/${USERNAME}/soma-retargeter

RUN git clone https://github.com/NVIDIA/soma-retargeter.git ${SOMA_RETARGETER_DIR} --branch v0.1.0 && \
    cd ${SOMA_RETARGETER_DIR} && \
    git lfs install && \
    git lfs pull && \
    . ${CUROBO_VENV}/bin/activate && \
    uv pip install -e . --extra-index-url https://pypi.nvidia.com --prerelease allow


# Auto-activate cuRobo virtual environment in interactive shells
RUN echo "" >> /home/${USERNAME}/.bashrc && \
    echo "# cuRobo virtual environment" >> /home/${USERNAME}/.bashrc && \
    echo "if [ -f ${CUROBO_VENV}/bin/activate ]; then" >> /home/${USERNAME}/.bashrc && \
    echo "    source ${CUROBO_VENV}/bin/activate" >> /home/${USERNAME}/.bashrc && \
    echo "fi" >> /home/${USERNAME}/.bashrc



########################################################################################################################
# Cleanup
########################################################################################################################


USER root
# Clear cache
RUN apt autoclean -y && apt autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pitch to avoid removing all content in ~/.cache
RUN sed -i "s|rm -rf /tmp/.X\* ~/.cache|rm -rf /tmp/.X\* ~/.cache/gstreamer\* ~/.cache/ksplash ~/.cache/nvidia ~/.cache/plasma\* ~/.cache/qt\* ~/.cache/ksycoca5\* ~/.cache/motd.legal-displayed|g" /etc/entrypoint.sh




### Proxy Setup

USER ${USERNAME}

COPY --chown=${USERNAME}:${USERNAME} ${RESOURCES_DIR}/proxy_utils.sh /home/${USERNAME}/proxy_utils.sh

RUN chmod +x /home/${USERNAME}/proxy_utils.sh && \
    echo "" >> /home/${USERNAME}/.bashrc && \
    echo "source /home/${USERNAME}/proxy_utils.sh" >> /home/${USERNAME}/.bashrc && \
    echo "" >> /home/${USERNAME}/.bashrc && \
    echo "if [ \"\$SHELL_AUTO_PROXY\" = \"true\" ]; then" >> /home/${USERNAME}/.bashrc && \
    echo "    proxy" >> /home/${USERNAME}/.bashrc && \
    echo "fi" >> /home/${USERNAME}/.bashrc && \
    echo "" >> /home/${USERNAME}/.bashrc && \
    echo "export DISPLAY=:20" >> /home/${USERNAME}/.bashrc


########################################################################################################################

# Restore User
USER ${USERNAME}
