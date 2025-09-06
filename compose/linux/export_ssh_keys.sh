rm -rf .ssh_keys

# Get all containers id 
containers=$(docker ps -q --filter "name=webrtc")

# Loop through each container and copy the SSH keys
for container in $containers; do
  container_name=$(docker inspect --format '{{.Name}}' $container | sed 's/\///')
  mkdir -p .ssh_keys/$container_name
  docker cp $container:/export_keys/id_rsa.pub .ssh_keys/$container_name/id_rsa.pub
  docker cp $container:/export_keys/id_rsa .ssh_keys/$container_name/id_rsa
  chmod 600 .ssh_keys/$container_name/id_rsa
  chmod 644 .ssh_keys/$container_name/id_rsa.pub
  zip -r .ssh_keys/$container_name.zip .ssh_keys/$container_name
done


