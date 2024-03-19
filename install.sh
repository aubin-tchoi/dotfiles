#!/bin/bash

# Define a function which rename a `target` file to `target.backup` if the file
# exists and if it's a 'real' file, ie not a symlink
backup() {
  target=$1
  if [ -e "$target" ]; then
    if [ ! -L "$target" ]; then
      mv "$target" "$target.backup"
      echo "-----> Moved your old $target config file to $target.backup"
    fi
  fi
}

symlink() {
  file=$1
  link=$2
  if [ ! -e "$link" ]; then
    echo "-----> Symlinking your new $link"
    ln -s "$file" "$link"
  fi
}

# ZSH
sudo apt install -y zsh
# Oh-my-zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

# Plugins
ZSH_PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/plugins
mkdir -p "$ZSH_PLUGINS_DIR"
if [ ! -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  echo "-----> Installing zsh plugin 'zsh-autosuggestions'..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR"/zsh-autosuggestions
  echo "-----> Installing zsh plugin 'zsh-syntax-highlighting'..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_PLUGINS_DIR"/zsh-syntax-highlighting
  echo "-----> Installing zsh plugin 'you-should-use'..."
  git clone https://github.com/MichaelAquilina/zsh-you-should-use.git "$ZSH_PLUGINS_DIR"/you-should-use
  echo "-----> Installing zsh plugin 'zsh-bat'..."
  git clone https://github.com/fdellwing/zsh-bat.git "$ZSH_PLUGINS_DIR"/zsh-bat
fi

# bat: prettier cat
sudo apt-get install -y bat
sudo ln -s /bin/batcat /bin/bat

# Install powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"/themes/powerlevel10k

# Backup old config files and symlink new ones
for name in gitconfig gitignore zbconfig zshrc config/terminator/config p10k.zsh; do
  if [ ! -d "$name" ]; then
    target="$HOME/.$name"
    backup "$target"
    symlink "$PWD"/$name "$target"
  fi
done

# Compilation stuff
sudo apt-get install -y build-essential libtool linux-source linux-headers-"$(uname -r)" distcc ccache ninja-build

# Terminator
sudo apt-get install -y terminator
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/terminator 50
update-alternatives --set x-terminal-emulator /usr/bin/terminator

# VSCode
sudo snap install code --classic
# CloudCompare
sudo snap install cloudcompare --edge
sudo snap connect cloudcompare:removable-media :removable-media
# CMake
sudo snap install cmake

# Useful third parties
sudo apt-get install -y curl wget mlocate htop git gnome-tweaks meld adwaita-icon-theme-full trash-cli xclip zip unzip

# Fonts and theme
curl -SL https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip -o JetBrainsMono-2.304.zip
unzip JetBrainsMono-2.304.zip "fonts/ttf/*.ttf" -d "JetBrainsMono"
sudo cp JetBrainsMono/fonts/ttf/*.ttf /usr/share/fonts/
rm JetBrainsMono-2.304.zip
rm -r JetBrainsMono

gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.gedit.preferences.editor scheme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface gtk-enable-primary-paste false
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'areas'

# Refresh the current terminal with the newly installed configuration
exec zsh

echo "👌 You're all set!"
