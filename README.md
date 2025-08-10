# Remote Isaac Lab Docker

## 1. How to use

1. Clone this repository.

    ```bash
    git clone https://github.com/XinyuKhan/remote_isaac_lab_docker.git
    cd remote_isaac_lab_docker/compose/linux
    ```

2. Create a `.env` file in the `compose/linux` directory based on the provided `.env.example` file. Fill in the required environment variables, especially the SSH keys and Coturn server details.


3. Build and run the Docker containers using Docker Compose.

    ```bash
    make dev_up
    ```

4. Access the WebRTC application by navigating to `https://localhost:8080` in your web browser. Use the password specified in the `.env` file to log in. Username is `ubuntu`.

5. Access the container via SSH for development purposes.

    export ssh keys from container
    ```bash
    ./export_ssh_keys.sh
    ```
    login via ssh
    ```bash
    ssh -p 2220 -i ./ssh_keys/id_rsa ubuntu@localhost
    ```