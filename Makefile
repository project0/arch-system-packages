export PKGDEST ?= $(PWD)/dist
export PKGEXT  := .pkg.tar.zst
export PKGREL  := 1

GPG_FINGERPRINT ?=
ifeq ($(GPG_FINGERPRINT),)
MAKEPKG_ARGS :=
REPO_ADD_ARGS :=
else
MAKEPKG_ARGS := --sign --key $(GPG_FINGERPRINT)
REPO_ADD_ARGS := --sign --key $(GPG_FINGERPRINT)
endif

AUR_DIR = $(PWD)/pkgbuild/aur

.PHONY: all clean update-integrity update-db/*
all: system packages aur
clean:
	rm -Rf $(PKGDEST) $(AUR_DIR)
# build all packages
.PHONY: 	pkgbuild/packages/* pkgbuild/system/* package system aur
packages:	pkgbuild/packages/* update-db/packages
system:
	$(MAKE) -j pkgbuild/system/*
	$(MAKE) update-db/system
aur: 		pkgbuild/aur/shim-signed pkgbuild/aur/yay-bin update-db/aur

# per package target
pkgbuild/system/* : |  $(PKGDEST)/project0-system
	updpkgsums $@/PKGBUILD || true
	(cd $@ && PKGDEST=$(PKGDEST)/project0-system makepkg $(MAKEPKG_ARGS) -s -f --cleanbuild)

pkgbuild/packages/* : | $(PKGDEST)/project0-packages
	updpkgsums $@/PKGBUILD
	(cd $@ && PKGDEST=$(PKGDEST)/project0-packages makepkg $(MAKEPKG_ARGS) -s -f --cleanbuild)

# build some dependent aur packages
pkgbuild/aur/% : | $(PKGDEST)/project0-aur
	git clone https://aur.archlinux.org/$(subst pkgbuild/aur/,,$@).git $@
	(cd $@ && PKGDEST=$(PKGDEST)/project0-aur makepkg $(MAKEPKG_ARGS) -s -f --cleanbuild)

update-db/%:
	repo-add $(REPO_ADD_ARGS) $(PKGDEST)/project0-$(subst update-db/,,$@)/project0-$(subst update-db/,,$@).db.tar \
		$(PKGDEST)/project0-$(subst update-db/,,$@)/*$(PKGEXT)

.PRECIOUS: $(PKGDEST)/%
$(PKGDEST)/% :
	mkdir -p $@

# run a local repo
.PHONY: run-local

REPO_URL ?= http://$(shell ip route get 8.8.8.8 | tr -s ' ' | cut -d' ' -f7)

bootstrap-script:
	@echo 'curl -sL $(REPO_URL)/key.asc | pacman-key -a -'
	@echo 'pacman-key --lsign-key $(GPG_FINGERPRINT)'
	@echo curl "$(REPO_URL)/bin/install.sh" -o /tmp/project0-bootstrap-install.sh
	@echo curl "$(REPO_URL)/bin/disk.sh" -o /tmp/project0-bootstrap-disk.sh
	@echo chmod a+x /tmp/project0-bootstrap-install.sh /tmp/project0-bootstrap-disk.sh
	@echo "# Setup disk: /tmp/project0-bootstrap-disk.sh /dev/disk <true:encrypt>'"
	@echo "# Install arch: /tmp/project0-bootstrap-install.sh $(REPO_URL)'"

repo-readme:
	@echo '# Arch Linux System Packages Repo'
	@echo '> Note: This page is auto generated!'
	@echo
	@echo '## Init Install scripts'
	@echo '```bash'
	$(MAKE) -s bootstrap-script
	@echo '```'
	@echo
	@echo '## Pacman config'
	@echo '```ini'
	sed "s!http://127.0.0.1:8888/dist!$(REPO_URL)!" repo.conf
	@echo
	@echo '```'
	@echo
	@echo '## Key'
	@echo 'Fingerprint `$(GPG_FINGERPRINT)`'
	@echo
	@echo '[Public Key]($(REPO_URL)/key.asc)'
	@echo '```bash'
	@echo 'curl -sL $(REPO_URL)/key.asc | gpg'
	@echo 'curl -sL $(REPO_URL)/key.asc | sudo pacman-key -a -'
	@echo 'sudo pacman-key --lsign-key $(GPG_FINGERPRINT)'
	@echo '```'

run-local:
	@echo "http://$(ip):8888/dist"
	@echo
	@echo ">> Install new machine:"
	@echo curl "http://$(ip):8888/bin/install.sh" -o /tmp/install.sh
	@echo curl "http://$(ip):8888/bin/disk.sh" -o /tmp/disk.sh
	@echo chmod +x /tmp/install.sh  /tmp/disk.sh
	@echo
	@echo "/tmp/disk.sh /dev/ <true:encrypt>"
	@echo /tmp/install.sh \'http://$(ip):8888/dist/\$$repo\'
	@echo
	@echo ">> Setup local repo on existing systems"
	@echo curl "http://$(ip):8888/repo.conf" "| sed 's/127.0.0.1/$(ip)/'" "> /etc/pacman.d/10-local-repo.conf && cat /etc/pacman.d/10-local-repo.conf >> /etc/pacman.conf"
	python3 -m http.server -b 0.0.0.0 8888
