# Disposable test environment for install-1password.sh (Ubuntu).
#
# SAFETY: this image exists so the install script is tested ONLY inside a
# throwaway container and NEVER on the host machine. Do not run the install
# script directly on your laptop.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Tools the install script relies on, plus `sudo` — containers ship without it,
# and the script's whole privilege model is built around sudo.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      sudo curl gnupg ca-certificates debsig-verify \
 && rm -rf /var/lib/apt/lists/*

# Run as a non-root user with sudo so the real code path (sudo -v, sudo tee,
# sudo apt) is actually exercised — running as root would skip it entirely.
# Grant sudo ONLY via this NOPASSWD drop-in (not the `sudo` group): the script's
# `sudo -v` only succeeds without a tty when every privilege is NOPASSWD, and the
# default `%sudo` rule requires a password. The password "test" is also set so
# you can exercise the interactive sudo prompt by hand in shell mode.
RUN useradd -m -s /bin/bash tester \
 && echo 'tester:test' | chpasswd \
 && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
 && chmod 0440 /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester

# Self-contained copy so the image works on its own. run-test.sh also mounts the
# live script over this path so you can edit-and-rerun without rebuilding.
COPY --chown=tester:tester install-1password.sh ./install-1password.sh

CMD ["bash"]
