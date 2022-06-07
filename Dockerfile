FROM archlinux

RUN pacman -Sy --noconfirm git make pacman-contrib sudo binutils openssh && \
    echo 'Defaults   !authenticate' > /etc/sudoers && \
    echo 'ALL ALL=(ALL) ALL' >> /etc/sudoers && \
    chown -c root:root /etc/sudoers && \
    chmod -c 0440 /etc/sudoers && \
    useradd -u 1001 -d /home/makepkg -m makepkg && \
    rm -rvf /var/cache/pacman/pkg/

ENV HOME /home/makepkg
USER 1001