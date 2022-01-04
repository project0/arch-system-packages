export PKGDEST := $(PWD)/dist
export PKGEXT  := .pkg.tar.zst
export PKGREL  := 1

AUR_DIR = $(PWD)/aur

.PHONY: all clean update-integrity update-db/*
all: system packages aur
clean:
	rm -Rf $(PKGDEST) $(AUR_DIR)

update-db/%: $(PKGDEST)
	repo-add $(PKGDEST)/project0-$(subst update-db/,,$@)/project0-$(subst update-db/,,$@).db.tar \
		$(PKGDEST)/project0-$(subst update-db/,,$@)/*$(PKGEXT)

$(PKGDEST)/% :
	mkdir -p $@
$(AUR_DIR):
	mkdir -p $(AUR_DIR)

# build all packages
.PHONY: pkgbuild/packages/* pkgbuild/system/* package system
packages: pkgbuild/packages/* update-db/packages
system: pkgbuild/system/* update-db/system

# per package target
pkgbuild/system/* : |  $(PKGDEST)/project0-system
	updpkgsums $@/PKGBUILD
	(cd $@ && PKGDEST=$(PKGDEST)/project0-system makepkg -s -f)

pkgbuild/packages/* : | $(PKGDEST)/project0-packages
	updpkgsums $@/PKGBUILD
	(cd $@ && PKGDEST=$(PKGDEST)/project0-packages makepkg -s -f)

# build some dependent aur packages
.PHONY: aur
aur: aur/shim-signed aur/yay-bin update-db/aur
aur/% : | $(AUR_DIR) $(PKGDEST)/project0-aur
	git clone https://aur.archlinux.org/$(subst aur/,,$@).git $@
	(cd $@ && PKGDEST=$(PKGDEST)/project0-aur makepkg -s)

# run a lcaol repo
.PHONY: run-local
ip = $(shell ip route get 8.8.8.8 | tr -s ' ' | cut -d' ' -f7)
run-local:
	@echo "http://$(ip):8888/dist"
	@echo
	@echo curl "http://$(ip):8888/bin/install.sh" -o /tmp/install.sh
	@echo curl "http://$(ip):8888/bin/disk.sh" -o /tmp/disk.sh
	@echo chmod +x /tmp/install.sh  /tmp/disk.sh
	@echo
	@echo /tmp/disk.sh /dev/
	@echo /tmp/install.sh \'http://$(ip):8888/dist/\$$repo\'
	@echo
	python3 -m http.server -b 0.0.0.0 8888
