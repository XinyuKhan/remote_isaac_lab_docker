ARG FROM_IMAGE="ubuntu:22.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# store current user in USERNAME
ENV USERNAME=${USER:-root}


# switch to root user to install dependencies
USER root

# Install Basic Dependencies


RUN apt update && DEBIAN_FRONTEND=noninteractive \
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
    btop \
    tmux \
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


# Set environment variables for Miniconda installation
ENV CONDA_DIR=/opt/conda
ENV PATH=$CONDA_DIR/bin:$PATH

# Install conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniconda.sh && \
    ${CONDA_DIR}/bin/conda clean -afy

ENV CONDA_DIR=/opt/conda \
    PATH=$CONDA_DIR/bin:$PATH    

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    conda create -n env_isaaclab python=3.10

RUN conda init bash && \
    echo "export PATH=/opt/conda/bin:\$PATH" >> /home/${USERNAME}/.bashrc && \
    echo "conda activate env_isaaclab" >> /home/${USERNAME}/.bashrc

# Disable pip cache globally so all pip invocations (including those inside
# isaaclab.sh and conda run subshells) do not leave wheels/HTTP caches in the image.
# Use both env vars and a system-wide pip.conf for belt-and-suspenders.
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
RUN mkdir -p /etc && printf '[global]\nno-cache-dir = true\ndisable-pip-version-check = true\n' > /etc/pip.conf

SHELL ["conda", "run", "-n", "env_isaaclab", "-v", "--no-capture-output", "/bin/bash", "-c"]


RUN python -m pip install --upgrade pip && \
    python -m pip install 'isaacsim[all,extscache]==4.5.0' --extra-index-url https://pypi.nvidia.com && \
    python -m pip install -U torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128 && \
    python -m pip install "setuptools<80" "wheel" && \
    python -m pip install --no-build-isolation "flatdict==4.0.1" && \
    conda clean -afy && \
    rm -rf /root/.cache/pip /home/${USERNAME}/.cache/pip /tmp/*

RUN git clone --depth 1 https://github.com/isaac-sim/IsaacLab.git -b v2.1.0 /home/${USERNAME}/IsaacLab


ENV TERM=xterm-256color
RUN cd /home/${USERNAME}/IsaacLab && \
    yes Y | ./isaaclab.sh -i && \
    python -m pip install -U torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128 && \
    conda clean -afy && \
    rm -rf /root/.cache/pip /home/${USERNAME}/.cache/pip /tmp/*

SHELL ["/bin/sh", "-c"]



########################################################################################################################
# Cleanup
########################################################################################################################


USER root
# Clear cache
RUN apt autoclean -y && apt autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -rf /opt/conda/pkgs/* && \
    find /opt/conda -depth -type d -name __pycache__ -exec rm -rf {} + && \
    find /home/${USERNAME}/IsaacLab -depth -type d -name __pycache__ -exec rm -rf {} +

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