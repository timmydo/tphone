
.PHONY: default download deps add-ssh-keys
default: build
download: debian-arm64.qcow2
deps:
	sudo apt-get install qemu-utils qemu-efi-aarch64 qemu-system-arm

debian-arm64.qcow2:
	curl -Lo debian-arm64.qcow2 'https://cdimage.debian.org/cdimage/openstack/current/debian-10.2.0-openstack-arm64.qcow2'

add-ssh-keys: debian-arm64.qcow2
# this is broken because the debian user does not exist anymore
	sudo modprobe nbd
	sudo qemu-nbd -c /dev/nbd0 debian-arm64.qcow2
	sudo mount /dev/nbd0p2 /mnt
	ssh-add -L > /mnt/home/debian/.ssh/authorized_keys
	sudo umount /mnt
	sudo qemu-nbd -d /dev/nbd0

gen:
	mkdir gen

gen/meta-data: gen
	printf "instance-id: local01\nlocal-hostname: cloudimg" > gen/meta-data

gen/user-data: gen
	printf "#cloud-config\npassword: passw0rd\nchpasswd: { expire: False }\nssh_pwauth: True\n" > gen/user-data

gen/seed.img: meta-data.yaml user-data.yaml
	cloud-localds -v gen/seed.img user-data.yaml meta-data.yaml

# not used
gen/seed.iso: gen/meta-data gen/user-data gen/cloud-config
	cd gen && genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data

build: debian-arm64.qcow2 gen/seed.img
	echo test

#	-smbios 'type=1,serial=ds=nocloud;s=/'
run: debian-arm64.qcow2 gen/seed.img
	qemu-system-aarch64 -m 2G -M virt -cpu cortex-a53 \
	-bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
	-drive if=none,file=debian-arm64.qcow2,id=hd0 -device virtio-blk-device,drive=hd0 \
	-drive if=none,file=gen/seed.img,format=raw,id=cidata -device virtio-blk-device,drive=cidata \
	-device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp:127.0.0.1:5555-:22 \
	-nographic