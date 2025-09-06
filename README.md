# Remote Isaac Lab Docker

## 1. How to use

1. Clone this repository.

    ```bash
    git clone https://github.com/XinyuKhan/remote_isaac_lab_docker.git
    cd remote_isaac_lab_docker/compose/linux
    ```

2. Create a `.env` file in the `compose/linux` directory based on the provided `.env.example` file. Fill in the required environment variables, especially the SSH keys and Coturn server details.


4. Run the download script to download the required dependencies into the `compose/linux/.downloads` directory.

    ```bash
    ./download.sh
    ```

    **Note**: If you want to re-download certain items or change the specific download content, please edit the `download.sh` script and the corresponding Dockerfile content accordingly.
5. Build and run the Docker containers using Docker Compose.

    ```bash
    make dev_up
    ```

6. Access the WebRTC application by navigating to `https://localhost:8080` (IsaacLab) or `https://localhost:8081` (Gym) in your web browser. Use the password specified in the `.env` file to log in. Username is `ubuntu`.

7. Access the container via SSH for development purposes.

    export ssh keys from container
    ```bash
    ./export_ssh_keys.sh
    ```
    login via ssh (Isaac Lab container)
    ```bash
    ssh -p 2220 -i ./ssh_keys/id_rsa ubuntu@localhost
    ```
    login via ssh (Gym container)
    ```bash
    ssh -p 2221 -i ./ssh_keys/id_rsa ubuntu@localhost
    ```