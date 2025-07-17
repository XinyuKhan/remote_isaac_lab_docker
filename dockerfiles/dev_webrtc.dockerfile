ARG FROM_IMAGE="ubuntu:22.04"
FROM ${FROM_IMAGE}

ARG RESOURCES_DIR="resources"

# store current user in USERNAME
ENV USERNAME=${USER:-root}


# switch to root user to install dependencies
USER root

# Install Basic Dependencies


RUN --mount=type=cache,target=/var/cache/apt \
    apt update && DEBIAN_FRONTEND=noninteractive \
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
    build-essential

USER ${USERNAME}

RUN git clone https://github.com/isaac-sim/IsaacSim.git /home/${USERNAME}/Projects/IsaacSim && \
    cd /home/${USERNAME}/Projects/IsaacSim && \
    git checkout 533a16022375a8fc3931212a9b513da2ad4277cc && \
    git lfs install && \
    git lfs pull



RUN cd /home/${USERNAME}/Projects/IsaacSim && \
    touch .eula_accepted && \
    ./build.sh


RUN git clone -b feature/isaacsim_5_0 https://github.com/isaac-sim/IsaacLab.git /home/${USERNAME}/Projects/IsaacLab && \
    cd /home/${USERNAME}/Projects/IsaacLab && \
    ln -s ../IsaacSim/_build/linux-x86_64/release _isaac_sim

ENV TERM xterm-256color    
RUN cd /home/${USERNAME}/Projects/IsaacLab && \
    ./isaaclab.sh -i


USER root
# Clear cache
RUN apt autoclean && apt autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pitch to avoid removing all content in ~/.cache
RUN sed -i "s|sudo rm -rf /tmp/.X\* ~/.cache|sudo rm -rf /tmp/.X* \&\& sudo find ~/.cache -mindepth 1 -maxdepth 1 ! -name 'pip' ! -name 'ov' ! -name 'uv' ! -name 'packman' -exec rm -rf {} +|g" /etc/entrypoint.sh



# Restore User
USER ${USERNAME}