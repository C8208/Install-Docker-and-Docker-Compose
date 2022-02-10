echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# install docker-ce
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

#  Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker

# create user group and add user to that group
sudo usermod -aG docker $USER

# To avoid performing a login again, you can simply run
newgrp docker

#  install docker compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose 

#  Verify

version: '3.7'
services:
  jenkins:
    build: .  
    image: finspire_jenkins:lts
    container_name: jenkins
    privileged: true
    restart: always
    ports:
      - "50000:50000"
      - "8080:8080"
    networks:
      - finspire 
    volumes:
      - jenkins-log:/var/log/jenkins
      - jenkins-data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/docker/bind-mounts/jenkins/downloads:/var/jenkins_home/downloads
      - /usr/bin/docker:/usr/bin/docker
        #- $SSH_AUTH_SOCK:$SSH_AUTH_SOCK
        #- $HOME/.ssh:/etc/ssh
        #- $HOME/.ssh/config/devops:/etc/ssh/devops
    environment:
      - VIRTUAL_HOST=jenkins.finspire.tech
      - VIRTUAL_PORT=8080
      - JAVA_OPTS=-Xmx4g
      - LETSENCRYPT_HOST=jenkins.finspire.tech
      - LETSENCRYPT_EMAIL=admin@finspiretech.com
        #- SSH_AUTH_SOCK=/ssh-agent
  registry:
    image: registry:2
    container_name: registry
    restart: always
    ports:
      - "5000:5000"
    environment:
      #REGISTRY_AUTH: htpasswd
      #REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      #REGISTRY_AUTH_HTPASSWD_PATH: /auth/registry.password
      #REGISTRY_HTTP_TLS_CERTIFICATE: /certs/finspire.crt
      #REGISTRY_HTTP_TLS_KEY: /certs/finspire.key
      VIRTUAL_HOST: registry.finspire.tech
      VIRTUAL_PORT: 5000
      LETSENCRYPT_HOST: registry.finspire.tech
      LETSENCRYPT_EMAIL: admin@finspiretech.com
    volumes:
      - /mnt:/var/lib/registry
      - /opt/registry/auth:/auth
      - /opt/registry/data:/data
      - /opt/certs:/certs
    networks:
      - finspire
  nexus:
    image: sonatype/nexus3:3.34.0 
    container_name: nexus
    environment:
      - VIRTUAL_HOST=nexus.finspire.tech
      - VIRTUAL_PORT=8081
      - LETSENCRYPT_HOST=nexus.finspire.tech
      - LETSENCRYPT_EMAIL=admin@finspiretech.com
    volumes:
      - nexus-data:/nexus-data
    restart: always
    networks:
      - finspire
  sonarqube:
    image: sonarqube:8.9.2-developer 
    container_name: sonar
    environment:
      - VIRTUAL_HOST=sonar.finspire.tech
      - VIRTUAL_PORT=9123
      - LETSENCRYPT_HOST=sonar.finspire.tech
      - LETSENCRYPT_EMAIL=admin@finspiretech.com
      - sonar.jdbc.url=jdbc:postgresql://postgres:5432/sonarqube
      - sonar.jdbc.username=sonar
      - sonar.jdbc.password=sonarQ123
    external_links:
      - postgres
    networks:
      - finspire
    volumes:
      - /opt/sonarqube/conf:/opt/sonarqube/conf
      - /opt/sonarqube/data:/opt/sonarqube/data
      - /opt/sonarqube/extensions:/opt/sonarqube/extensions
volumes:
  sonarqube_conf:
  sonarqube_data:
  sonarqube_extensions:
  postgresql:
  postgresql_data:
  jenkins-data:
  jenkins-log:
  nexus-data:
  registry-data:
networks:
  default:
    external:
      name: finspire 
volumes:
  jenkins-data:
  jenkins-log:
  nexus-data:
networks:
  finspire:
    name: finspire
    driver: bridge
FROM jenkins/jenkins:2.319
USER root
RUN apt-get update && \
apt-get -y install apt-transport-https \
    ca-certificates \
    curl \
    wget \
    gnupg2 \
    software-properties-common && \
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey && \
add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable" && \
apt-get update && \
apt-get -y install docker-ce
RUN usermod -a -G docker jenkins
