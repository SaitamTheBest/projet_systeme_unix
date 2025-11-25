#!/bin/bash

# Mise à jour du serveur
echo "Mise à jour du serveur"
sudo apt update
sudo apt upgrade -y


# Installation de Git
echo "Vérification de Git..."
if ! command -v git >/dev/null 2>&1; then # Permet la vérification de la commande sur la machine
  echo "Installation de Git..."
  sudo apt install git -y
else
  echo "Git déjà installé"
fi


# Intallation de Nginx
echo "Vérification de Nginx..."
if ! command -v nginx >/dev/null 2>&1; then # Permet la vérification de la commande sur la machine
  echo "Installation de Nginx..."
  sudo apt install nginx -y
  sudo systemctl enable nginx
  sudo systemctl start nginx
else
  echo "Nginx déjà installé"
fi

# 3. Installation de NVM + Node 24
echo "Installation de NVM + Node.js..."

# Voir docs pour installation de NVM et Node https://nodejs.org/en/download
if [ ! -d "$HOME/.nvm" ]; then # Permet la vérification des packages de NVM sur la machine
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

nvm install 24
nvm use 24

echo "Node version: $(node -v)"
echo "NPM version: $(npm -v)"


# Récupération projet via git distant
APP_DIR="$HOME/deployment_project" # Même en récupérant le script bash, on récupérera correctement le projet
REPO_URL="https://github.com/SaitamTheBest/projet_systeme_unix.git"

if [ ! -d "$APP_DIR" ]; then
  echo "Clonage du dépôt..."
  git clone "$REPO_URL" "$APP_DIR"
else
  echo "Mise à jour du dépôt..."
  cd "$APP_DIR"
  git pull
fi

# Build React
cd "$APP_DIR/projetweb" || { echo "Dossier projetweb introuvable"; exit 1; }

echo "Installation des dépendances"
npm install

echo "Build en cours..."
npm run build


# Déploiement
DEPLOY_PATH="/var/www/monapp"

echo "Déploiement dans $DEPLOY_PATH"

sudo mkdir -p $DEPLOY_PATH
sudo rm -rf $DEPLOY_PATH/*
sudo cp -r build/* $DEPLOY_PATH/


# Configuration NGINX
echo "Configuration NGINX..."

NGINX_CONF="/etc/nginx/sites-available/monapp"

if [ ! -f "$NGINX_CONF" ]; then
  sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    root /var/www/monapp;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOF

  sudo ln -s /etc/nginx/sites-available/monapp /etc/nginx/sites-enabled/
fi


# Reload du service NGINX
echo "Reload NGINX..."
DEFAULT_SITE="/etc/nginx/sites-enabled/default"
if [ -f "$DEFAULT_SITE" ]; then
    echo "Suppression du site par défaut..."
    sudo rm "$DEFAULT_SITE"
fi
sudo systemctl reload nginx

SERVER_IP=$(ip -4 addr show | grep inet | grep -v 127 | awk '{print $2}' | cut -d/ -f1) # Récupération adresse IP publique de la machine
echo "Déploiement terminé. Site ouvert sur http://$SERVER_IP/"
