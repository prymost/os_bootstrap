# If you come from bash you might have to change your $PATH.
# Modern Homebrew path handling for both Intel and Apple Silicon (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $(uname -m) == "arm64" ]]; then
        # Apple Silicon
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    else
        # Intel
        export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
    fi
fi

export PATH=$HOME/bin:$PATH

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"
# Tweak agnoster theme to remove username and machine name 'username@hostname'
DEFAULT_USER=$USER

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

# Platform-specific plugin configurations
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS plugins
    plugins=(git aws docker zsh-autosuggestions)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux plugins (includes WSL)
    plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker python pip ruby rbenv)
else
    # Default plugins
    plugins=(git zsh-autosuggestions)
fi

source $ZSH/oh-my-zsh.sh

# autosuggestions
export WORDCHARS='_'
bindkey "^ " forward-word

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='micro'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias zconfig="code ~/.zshrc"
alias zrefresh="source ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Git Aliases
alias gcm="git checkout master"
alias rbtom="git rebase -i origin/master"

# Python3 by default (updated for modern Homebrew Python)
if command -v python3 &> /dev/null; then
    alias python="python3"
fi
if command -v pip3 &> /dev/null; then
    alias pip="pip3"
fi

# Pipenv
alias prp="pipenv run python"
export PIPENV_VENV_IN_PROJECT=true

# My desktop Linux aliases
alias ww="cd ${HOME}/Workspace"

# Hook up direnv
eval "$(direnv hook zsh)"

# Enhanced history configuration for all platforms
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# Platform-specific configurations
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux/WSL specific configurations

    # WSL specific aliases and functions
    if grep -q Microsoft /proc/version 2>/dev/null; then
        # WSL-specific configurations
        alias open='explorer.exe'
        alias code-here='code .'
        alias winhome='cd /mnt/c/Users/$USER'

        # Windows integration
        export BROWSER='/mnt/c/Program Files/Google/Chrome/Application/chrome.exe'
    fi
fi
