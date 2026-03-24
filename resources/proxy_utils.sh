
# export PROXY_ADDR=localhost
# export PROXY_PORT_HTTP=10808
# export PROXY_PORT_HTTPS=10808

# function to enbale proxy

proxy() {
    export http_proxy=http://$PROXY_ADDR:$PROXY_PORT_HTTP
    export https_proxy=http://$PROXY_ADDR:$PROXY_PORT_HTTPS
    export HTTP_PROXY=$http_proxy
    export HTTPS_PROXY=$https_proxy
    # export no_proxy to disable proxy for local addresses and reserved IPs
    export no_proxy="localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,169.254.0.0/16"
    export NO_PROXY=$no_proxy
    echo "Proxy enabled: $http_proxy, $https_proxy"
    echo "No Proxy: $NO_PROXY"
}

# function to disable proxy

unproxy() {
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY
    echo "Proxy disabled"
}

# function to set proxy for apt
apt_proxy() {
    echo "Acquire::http::Proxy \"http://$PROXY_ADDR:$PROXY_PORT_HTTP/\";" | sudo tee /etc/apt/apt.conf.d/99proxy
    echo "Acquire::https::Proxy \"http://$PROXY_ADDR:$PROXY_PORT_HTTPS/\";" | sudo tee -a /etc/apt/apt.conf.d/99proxy
    echo "Apt proxy set to: http://$PROXY_ADDR:$PROXY_PORT_HTTP/ and https://$PROXY_ADDR:$PROXY_PORT_HTTPS/"
}

# function to unset proxy for apt
apt_unproxy() {
    sudo rm -f /etc/apt/apt.conf.d/99proxy
    echo "Apt proxy unset"
}

# function to set proxy for git
git_proxy() {
    git config --global http.proxy http://$PROXY_ADDR:$PROXY_PORT_HTTP
    git config --global https.proxy http://$PROXY_ADDR:$PROXY_PORT_HTTPS
    echo "Git proxy set to: http://$PROXY_ADDR:$PROXY_PORT_HTTP and https://$PROXY_ADDR:$PROXY_PORT_HTTPS"
}

# function to unset proxy for git
git_unproxy() {
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    echo "Git proxy unset"
}

pip_proxy() {
    mkdir -p ~/.pip
    echo "[global]" > ~/.pip/pip.conf
    echo "proxy = http://$PROXY_ADDR:$PROXY_PORT_HTTP" >> ~/.pip/pip.conf
    echo "Pip proxy set to: http://$PROXY_ADDR:$PROXY_PORT_HTTP"
}

pip_unproxy() {
    rm -f ~/.pip/pip.conf
    echo "Pip proxy unset"
}
