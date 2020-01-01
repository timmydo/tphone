QEMU=qemu-system-aarch64
QEMUDISPLAY=gtk
#GFXDEVICE=virtio-gpu-pci
GFXDEVICE=VGA
DISKIMAGE=debian-arm64.qcow2
MEM=2G
SMP=4
BIOS=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd

.PHONY: default download deps touchdisk run build qemu-deps
default: run
download: $(DISKIMAGE)
qemu-deps:
	sudo apt-get install libgtk-3-dev libpixman-1-dev gettext

qemu-system-aarch64: qemu-deps
	git clone https://git.qemu.org/git/qemu.git
	cd qemu
	./configure --target-list=aarch64-softmmu --enable-gtk && make && sudo make install

deps:
	sudo apt-get install qemu-utils qemu-efi-aarch64 qemu-system-arm cloud-image-utils libvirt-clients

$(DISKIMAGE).orig:
	curl -Lo $(DISKIMAGE).orig 'https://cdimage.debian.org/cdimage/openstack/current/debian-10.2.0-openstack-arm64.qcow2'

touchdisk: $(DISKIMAGE).orig
	touch $(DISKIMAGE).orig

$(DISKIMAGE): $(DISKIMAGE).orig
	cp $(DISKIMAGE).orig $(DISKIMAGE)

gen:
	mkdir gen

gen/seed.img: gen meta-data.yaml user-data.yaml
	cloud-localds -v gen/seed.img user-data.yaml meta-data.yaml

build: $(DISKIMAGE) gen/seed.img
	@echo Done

#	-smbios 'type=1,serial=ds=nocloud;s=/'

run: $(DISKIMAGE) gen/seed.img
	@echo Use Ctrl-Alt-2 to go to boot console
	$(QEMU) -m $(MEM) -M virt -cpu cortex-a53 \
	-bios $(BIOS) \
	-drive if=none,file=$(DISKIMAGE),id=hd0 -device virtio-blk-device,drive=hd0 \
	-drive if=none,file=gen/seed.img,format=raw,id=cidata -device virtio-blk-device,drive=cidata \
	-device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp:127.0.0.1:5555-:22 \
	-smp $(SMP) \
	-display $(QEMUDISPLAY) \
	-device $(GFXDEVICE) \
	-device virtio-tablet-pci \
	-device virtio-keyboard-pci
