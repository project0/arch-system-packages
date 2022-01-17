export PKGDEST := $(PWD)/dist
export PKGEXT  := .pkg.tar.zst
export PKGREL  := 1

AUR_DIR = $(PWD)/pkgbuild/aur

.PHONY: all clean update-integrity update-db/*
all: system packages aur
clean:
	rm -Rf $(PKGDEST) $(AUR_DIR)
# build all packages
.PHONY: 	pkgbuild/packages/* pkgbuild/system/* package system aur
packages:	pkgbuild/packages/* update-db/packages
system: 	pkgbuild/system/* 	update-db/system
aur: 		pkgbuild/aur/shim-signed pkgbuild/aur/yay-bin update-db/aur

# per package target
pkgbuild/system/* : |  $(PKGDEST)/project0-system
	updpkgsums $@/PKGBUILD
	(cd $@ && PKGDEST=$(PKGDEST)/project0-system makepkg -s -f --cleanbuild)

pkgbuild/packages/* : | $(PKGDEST)/project0-packages
	updpkgsums $@/PKGBUILD
	(cd $@ && PKGDEST=$(PKGDEST)/project0-packages makepkg -s -f --cleanbuild)

# build some dependent aur packages
pkgbuild/aur/% : | $(PKGDEST)/project0-aur
	git clone https://aur.archlinux.org/$(subst pkgbuild/aur/,,$@).git $@
	(cd $@ && PKGDEST=$(PKGDEST)/project0-aur makepkg -s -f --cleanbuild)

update-db/%:
	repo-add $(PKGDEST)/project0-$(subst update-db/,,$@)/project0-$(subst update-db/,,$@).db.tar \
		$(PKGDEST)/project0-$(subst update-db/,,$@)/*$(PKGEXT)

.PRECIOUS: $(PKGDEST)/%
$(PKGDEST)/% :
	mkdir -p $@

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
	@echo /tmp/disk.sh /dev/ <true:encrypt>
	@echo /tmp/install.sh \'http://$(ip):8888/dist/\$$repo\'
	@echo
	python3 -m http.server -b 0.0.0.0 8888
