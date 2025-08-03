FROM julia:1.11

ARG TZ
ENV TZ="$TZ"

ARG JULIA_VERSION=1.11

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  build-essential \
  curl \
  wget \
  ca-certificates \
  lsb-release \
  nodejs \
  npm \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG USERNAME=julia
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Persist bash and zsh history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && touch /commandhistory/.zsh_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and Julia depot directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.julia && \
  chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.julia

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN wget "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" && \
  chmod +x zsh-in-docker.sh && \
  ./zsh-in-docker.sh \
    -t robbyrussell \
    -p git \
    -p ssh-agent \
    -p 'history-substring-search' \
    -a 'bindkey "\$terminfo[kcuu1]" history-substring-search-up' \
    -a 'bindkey "\$terminfo[kcud1]" history-substring-search-down' && \
  rm zsh-in-docker.sh

# Configure zsh history for the julia user
RUN echo 'export HISTFILE=/commandhistory/.zsh_history' >> /home/$USERNAME/.zshrc && \
  echo 'export HISTSIZE=10000' >> /home/$USERNAME/.zshrc && \
  echo 'export SAVEHIST=10000' >> /home/$USERNAME/.zshrc && \
  echo 'setopt SHARE_HISTORY' >> /home/$USERNAME/.zshrc

# Set up Julia development environment
USER $USERNAME

# Create Julia config directory - startup file will be copied by postCreateCommand
RUN mkdir -p /home/$USERNAME/.julia/config

# Set Julia depot path
ENV JULIA_DEPOT_PATH="/home/$USERNAME/.julia"

# Switch back to root for any final setup
USER root

# Copy and set up firewall initialization script
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# Switch back to user
USER $USERNAME