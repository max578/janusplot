# janusplot development container.
# Base: rocker/r-ver pinned to the package's R (>= 4.3.0) requirement.
FROM rocker/r-ver:4.5.2

# System libraries for building ggplot2, mgcv, and the vignette engine.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    pandoc \
    pandoc-citeproc \
    libcurl4-gnutls-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# pak for fast dependency resolution + devtools for iteration.
RUN R -q -e 'install.packages(c("pak", "devtools", "languageserver"), repos = "https://p3m.dev/cran/__linux__/jammy/latest")'

# Non-root VS Code user.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME
WORKDIR /workspaces/janusplot
