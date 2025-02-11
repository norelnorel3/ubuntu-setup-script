#!/bin/bash

# Variables
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_USER_HOME="/home/$TARGET_USER"
ZSHRC="$TARGET_USER_HOME/.zshrc"
ZSH_THEME="powerlevel10k/powerlevel10k"
COMMON_PACKAGES=(
    apt-transport-https
    ca-certificates
    curl
    gnupg
    software-properties-common
)
DEV_TOOLS=(
    terminator
    vim
    zsh
    git
    fonts-powerline
    ruby-full
    gnome-tweaks
    fzf
    wget
)
ZSH_PLUGINS=(
    git
    kubectl
    docker
    helm
    zsh-autosuggestions
    zsh-syntax-highlighting
    ansible
    oc
    vagrant
    ubuntu
    colorize
    kubectx
    brew
    fzf
    terraform
    aws
)

# Ensure /etc/apt/keyrings directory exists
echo "Creating /etc/apt/keyrings directory..."
sudo mkdir -p /etc/apt/keyrings
sudo chown root:root /etc/apt/keyrings
sudo chmod 0755 /etc/apt/keyrings

# Update and upgrade apt packages
echo "Updating and upgrading apt packages..."
sudo apt update && sudo apt upgrade -y || echo "Apt update/upgrade failed but continuing..."

# Install common packages
echo "Installing common packages..."
for pkg in "${COMMON_PACKAGES[@]}"; do
    sudo apt install -y "$pkg"
done

# Install development tools
echo "Installing development tools..."
for tool in "${DEV_TOOLS[@]}"; do
    sudo apt install -y "$tool"
done

# Create .zshrc if it doesn't exist
if [ ! -f "$ZSHRC" ]; then
    echo "Creating .zshrc file for $TARGET_USER..."
    sudo -u "$TARGET_USER" touch "$ZSHRC"
fi

# Install Oh My Zsh if not installed
if [ ! -d "$TARGET_USER_HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh for $TARGET_USER..."
    sudo -u "$TARGET_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Clone Powerlevel10k and plugins
echo "Cloning Powerlevel10k theme and plugins..."
sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$TARGET_USER_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$TARGET_USER_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$TARGET_USER_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

# Set Powerlevel10k theme in .zshrc
echo "Setting Zsh theme in .zshrc..."
if grep -q "^ZSH_THEME=" "$ZSHRC"; then
    sudo -u "$TARGET_USER" sed -i "s|^ZSH_THEME=.*|ZSH_THEME=\"$ZSH_THEME\"|" "$ZSHRC"
else
    echo "ZSH_THEME=\"$ZSH_THEME\"" | sudo -u "$TARGET_USER" tee -a "$ZSHRC"
fi

# Configure Zsh plugins in .zshrc
echo "Configuring Zsh plugins in .zshrc..."
if grep -q "^plugins=" "$ZSHRC"; then
    sudo -u "$TARGET_USER" sed -i "s|^plugins=.*|plugins=(${ZSH_PLUGINS[*]})|" "$ZSHRC"
else
    echo "plugins=(${ZSH_PLUGINS[*]})" | sudo -u "$TARGET_USER" tee -a "$ZSHRC"
fi

# Add Docker's official GPG key and repository, then install Docker
echo "Setting up Docker repository and installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker "$TARGET_USER"

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
mkdir -p "$TARGET_USER_HOME/.kube"

# Install Helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh && rm -f get_helm.sh

# Install lazygit
echo "Installing lazygit..."
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
rm -f lazygit lazygit.tar.gz

# Add custom configurations to .zshrc
echo "Adding custom configurations to .zshrc..."
CUSTOM_CONFIG=$(cat << 'EOF'
# Function to extract various archive types
ex () {
  if [ -f "$1" ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1   ;;
      *.gz)        gunzip $1    ;;
      *.tar)       tar xf $1    ;;
      *.tbz2)      tar xjf $1   ;;
      *.tgz)       tar xzf $1   ;;
      *.zip)       unzip $1     ;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1      ;;
      *.deb)       ar x $1      ;;
      *.tar.xz)    tar xf $1    ;;
      *.tar.zst)   unzstd $1    ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Set KUBECONFIG to include all YAML files in .kube directory
export KUBECONFIG=$(find "$TARGET_USER_HOME/.kube" -name "*.yaml" | tr '\n' ':')

# Aliases
alias k='kubectl'
alias vi='nvim'
alias ll='ls -la'
alias hi='helm upgrade --install --debug'
alias kcu='kubectl config use'
alias kcgc='kubectl config get-contexts'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get secret'
alias lg='lazygit'
alias values.py='python3 /home/norelm/My-Scripts/values.py'
EOF
)

# Append custom configurations if not already present
if ! grep -q "export KUBECONFIG=" "$ZSHRC"; then
    echo "$CUSTOM_CONFIG" | sudo -u "$TARGET_USER" tee -a "$ZSHRC" > /dev/null
fi


# Install VSCODE
sudo apt-get install wget gpg
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg

sudo apt install apt-transport-https -y 
sudo apt update
sudo apt install code -y 


# Install Lens
curl -fsSL https://downloads.k8slens.dev/keys/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/lens-archive-keyring.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/lens-archive-keyring.gpg] https://downloads.k8slens.dev/apt/debian stable main" | sudo tee /etc/apt/sources.list.d/lens.list > /dev/null
sudo apt update && sudo apt install lens  -y 

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -f awscliv2.zip

# Install eksctl
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin

# Change input swtich key to ALT+SHIFT
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L']"