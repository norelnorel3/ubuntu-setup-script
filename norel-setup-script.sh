#!/bin/bash

# =================================================================
# Development Environment Setup Script
# =================================================================
# Author: Norel Milihov
# Version: 1.0
# Tested on: Ubuntu 22.04 LTS
# Warning: This script has only been tested on Ubuntu 22.04.
#         Using it on other versions or distributions may lead to
#         unexpected results.
# 
# Description: This script automates the setup of a development
#              environment on Ubuntu systems. It includes installation
#              of common development tools, Docker, Kubernetes tools,
#              and various configurations.
# =================================================================
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

# Function to prompt user for yes/no
prompt_user() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Function to install if user agrees
install_if_agreed() {
    local prompt="$1"
    local install_function="$2"
    
    if prompt_user "$prompt"; then
        eval "$install_function"
    else
        echo "Skipping $prompt"
    fi
}

# Replace the show_progress function with this corrected version
show_progress() {
    local pid=$1
    local msg="$2"
    local width=50  # Fixed width for the progress bar
    local fill='#'
    local empty='.'
    
    while ps -p $pid > /dev/null; do
        for i in $(seq 1 100); do
            local filled=$(( i * width / 100 ))
            local empty_space=$((width - filled))
            
            # Create the bar with proper spacing
            printf "\r%-30s [" "$msg"  # Reduced fixed width for message
            printf "%${filled}s" "" | tr ' ' "$fill"
            printf "%${empty_space}s" "" | tr ' ' "$empty"
            printf "] %3d%%" $i
            
            sleep 0.1
            
            # Check if process is still running
            if ! ps -p $pid > /dev/null; then
                break
            fi
        done
    done
    
    # Ensure 100% at the end with proper spacing
    local filled=$width
    printf "\r%-30s [" "$msg"
    printf "%${filled}s" "" | tr ' ' "$fill"
    printf "] 100%%\n"
}

# Update the run_with_progress function
run_with_progress() {
    local msg="$1"
    local cmd="$2"
    local temp_file=$(mktemp)
    
    # Run command in background, redirect stderr to temp file
    (eval "$cmd") 2>"$temp_file" >/dev/null &
    show_progress $! "$msg"
    
    # Check if there were any errors
    if [ -s "$temp_file" ]; then
        # Read the error file content
        local error_content=$(<"$temp_file")
        
        # Filter out known non-error messages
        if [[ "$error_content" =~ "E:" ]] || [[ "$error_content" =~ "ERROR" ]]; then
            echo -e "\nError during $msg:"
            grep -E "^(E:|ERROR)" "$temp_file"
            rm "$temp_file"
            return 1
        fi
    fi
    rm "$temp_file"
    return 0
}

# Modify system_update function
system_update() {
    run_with_progress "Updating apt packages" "sudo apt update -y"
}

# Modify install_common_packages function
install_common_packages() {
    echo "Installing common packages..."
    for pkg in "${COMMON_PACKAGES[@]}"; do
        if ! run_with_progress "Installing $pkg" "sudo apt install -y $pkg"; then
            echo "Failed to install $pkg, continuing with remaining packages..."
        fi
    done
}

# Modify install_dev_tools function
install_dev_tools() {
    echo "Installing development tools..."
    for tool in "${DEV_TOOLS[@]}"; do
        if ! run_with_progress "Installing $tool" "sudo apt install -y $tool"; then
            echo "Failed to install $tool, continuing with remaining packages..."
        fi
    done
}

# Oh My Zsh installation function
install_oh_my_zsh() {
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

    # Configure Zsh theme and plugins
    configure_zsh

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
}

# Modify install_docker function
install_docker() {
    echo "Setting up Docker..."
    echo -n "Updating package index..."
    (sudo apt-get update > /dev/null 2>&1) &
    show_progress $! "Updating package index"
    
    echo -n "Installing Docker dependencies..."
    (sudo apt-get install -y ca-certificates curl > /dev/null 2>&1) &
    show_progress $! "Installing Docker dependencies"
    
    echo -n "Setting up Docker repository..."
    (
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    ) &
    show_progress $! "Setting up Docker repository"
    
    echo -n "Installing Docker..."
    (sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1) &
    show_progress $! "Installing Docker"
    
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$TARGET_USER"
}

# Kubectl installation function
install_kubectl() {
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    mkdir -p "$TARGET_USER_HOME/.kube"
}

# Helm installation function
install_helm() {
    echo "Installing Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh && rm -f get_helm.sh
}

# Lazygit installation function
install_lazygit() {
    echo "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm -f lazygit lazygit.tar.gz
}

# Modify install_vscode function
install_vscode() {
    echo "Installing VS Code..."
    echo -n "Installing dependencies..."
    (sudo apt-get install -y wget gpg > /dev/null 2>&1) &
    show_progress $! "Installing dependencies"
    
    echo -n "Setting up VS Code repository..."
    (
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f packages.microsoft.gpg
    ) &
    show_progress $! "Setting up VS Code repository"
    
    echo -n "Installing VS Code..."
    (sudo apt update > /dev/null 2>&1 && sudo apt install -y code > /dev/null 2>&1) &
    show_progress $! "Installing VS Code"
}

# Modify install_lens function
install_lens() {
    echo "Installing Lens..."
    echo -n "Setting up Lens repository..."
    (
        curl -fsSL https://downloads.k8slens.dev/keys/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/lens-archive-keyring.gpg > /dev/null
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/lens-archive-keyring.gpg] https://downloads.k8slens.dev/apt/debian stable main" | sudo tee /etc/apt/sources.list.d/lens.list > /dev/null
    ) &
    show_progress $! "Setting up Lens repository"
    
    echo -n "Installing Lens..."
    (sudo apt update > /dev/null 2>&1 && sudo apt install -y lens > /dev/null 2>&1) &
    show_progress $! "Installing Lens"
}

# AWS CLI installation function
install_aws_cli() {
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -f awscliv2.zip
}

# eksctl installation function
install_eksctl() {
    echo "Installing eksctl..."
    ARCH=amd64
    PLATFORM=$(uname -s)_$ARCH
    curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
    tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
    sudo mv /tmp/eksctl /usr/local/bin
}

# Configure input switch
configure_input_switch() {
    echo "Configuring input switch key to ALT+SHIFT..."
    gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>Shift_L']"
}

# Add the missing configure_zsh function
configure_zsh() {
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
}

# Main installation process
echo "Welcome to the Development Environment Setup Script!"
echo "This script will help you set up your development environment."
echo "First, you'll choose what to install, then we'll begin the installation process."
echo

# Declare associative array to store user choices
declare -A install_choices

echo "Please answer the following questions to customize your installation:"
echo "Note: System updates and common packages will be installed automatically."
echo

# Collect all user choices first
install_choices[dev_tools]=$(prompt_user "Install development tools (terminator, vim, zsh, etc)?" && echo "yes" || echo "no")
install_choices[oh_my_zsh]=$(prompt_user "Install Oh My Zsh with plugins?" && echo "yes" || echo "no")
install_choices[docker]=$(prompt_user "Install Docker?" && echo "yes" || echo "no")
install_choices[kubectl]=$(prompt_user "Install kubectl?" && echo "yes" || echo "no")
install_choices[helm]=$(prompt_user "Install Helm?" && echo "yes" || echo "no")
install_choices[lazygit]=$(prompt_user "Install Lazygit?" && echo "yes" || echo "no")
install_choices[vscode]=$(prompt_user "Install VS Code?" && echo "yes" || echo "no")
install_choices[lens]=$(prompt_user "Install Lens?" && echo "yes" || echo "no")
install_choices[aws_cli]=$(prompt_user "Install AWS CLI?" && echo "yes" || echo "no")
install_choices[eksctl]=$(prompt_user "Install eksctl?" && echo "yes" || echo "no")
install_choices[input_switch]=$(prompt_user "Configure input switch to ALT+SHIFT?" && echo "yes" || echo "no")

# Show installation summary
echo -e "\nInstallation Summary:"
echo "The following will be installed:"
echo "- System updates and common packages (automatic)"
for key in "${!install_choices[@]}"; do
    if [ "${install_choices[$key]}" = "yes" ]; then
        echo "- ${key//_/ }"
    fi
done

# Confirm installation
if prompt_user $'\nProceed with installation?'; then
    echo -e "\nStarting installation process...\n"
    
    # Ensure /etc/apt/keyrings directory exists
    echo "Creating /etc/apt/keyrings directory..."
    sudo mkdir -p /etc/apt/keyrings
    sudo chown root:root /etc/apt/keyrings
    sudo chmod 0755 /etc/apt/keyrings

    # Run system update and install common packages
    echo "Updating system and installing common packages..."
    system_update
    install_common_packages
    
    # Perform installations based on user choices
    [[ ${install_choices[dev_tools]} == "yes" ]] && install_dev_tools
    [[ ${install_choices[oh_my_zsh]} == "yes" ]] && install_oh_my_zsh
    [[ ${install_choices[docker]} == "yes" ]] && install_docker
    [[ ${install_choices[kubectl]} == "yes" ]] && install_kubectl
    [[ ${install_choices[helm]} == "yes" ]] && install_helm
    [[ ${install_choices[lazygit]} == "yes" ]] && install_lazygit
    [[ ${install_choices[vscode]} == "yes" ]] && install_vscode
    [[ ${install_choices[lens]} == "yes" ]] && install_lens
    [[ ${install_choices[aws_cli]} == "yes" ]] && install_aws_cli
    [[ ${install_choices[eksctl]} == "yes" ]] && install_eksctl
    [[ ${install_choices[input_switch]} == "yes" ]] && configure_input_switch
    
    echo -e "\nSetup complete! Please log out and log back in for all changes to take effect."
else
    echo "Installation cancelled."
    exit 1
fi