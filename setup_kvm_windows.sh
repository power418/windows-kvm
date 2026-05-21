#!/usr/bin/env bash

# ==============================================================================
# Setup KVM & QEMU Windows VM di CachyOS (Arch-based)
# ==============================================================================
# Script ini akan mengotomatisasi instalasi QEMU/KVM, mendeteksi GPU Anda,
# mengunduh driver VirtIO Windows, dan membuat script booting VM yang super optimal.
# ==============================================================================

# Definisikan warna untuk output yang menarik
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Password Anda (otomatis disuapkan ke sudo jika diperlukan)
PASSWORD="12345"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${PURPLE}  🚀 MEMULAI SETUP KVM/QEMU WINDOWS VM UNTUK AUTOCAD DI CACHYOS${NC}"
echo -e "${CYAN}======================================================================${NC}"

# ------------------------------------------------------------------------------
# Langkah 1: Deteksi Hardware & Driver GPU
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[1/5] Mendeteksi Hardware & GPU Anda...${NC}"

# Deteksi CPU
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name:[[:space:]]*//')
CPU_CORES=$(nproc)
echo -e "  - CPU: ${GREEN}${CPU_MODEL} (${CPU_CORES} Threads)${NC}"

# Deteksi Intel Iris Xe
INTEL_GPU=$(lspci | grep -i "VGA" | grep -i "Intel")
if [ -n "$INTEL_GPU" ]; then
    INTEL_PCI=$(echo "$INTEL_GPU" | awk '{print $1}')
    echo -e "  - Integrated GPU: ${GREEN}Intel Iris Xe (PCI ${INTEL_PCI})${NC}"
else
    echo -e "  - Integrated GPU: ${RED}Tidak terdeteksi${NC}"
fi

# Deteksi NVIDIA RTX
NVIDIA_GPU=$(lspci | grep -i -E "VGA|3D" | grep -i "NVIDIA")
if [ -n "$NVIDIA_GPU" ]; then
    NVIDIA_PCI=$(echo "$NVIDIA_GPU" | awk '{print $1}')
    echo -e "  - Dedicated GPU: ${GREEN}NVIDIA RTX (PCI ${NVIDIA_PCI})${NC}"
    # Dapatkan PCI IDs untuk VFIO jika nanti ingin passthrough
    NVIDIA_IDS=$(lspci -n -s "$NVIDIA_PCI" | awk '{print $3}')
    echo -e "    - PCI ID: ${YELLOW}${NVIDIA_IDS}${NC}"
else
    echo -e "  - Dedicated GPU: ${RED}NVIDIA Tidak terdeteksi${NC}"
fi

# ------------------------------------------------------------------------------
# Langkah 2: Instalasi KVM & QEMU Packages (Menggunakan Pacman di CachyOS)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[2/5] Menginstal QEMU, KVM, Virt-Manager, dan dependensi...${NC}"

# Gunakan password yang Anda berikan
echo "$PASSWORD" | sudo -S pacman -Sy --needed --noconfirm \
    qemu-desktop \
    libvirt \
    virt-manager \
    edk2-ovmf \
    dnsmasq \
    iptables-nft \
    dmidecode \
    guestfs-tools

if [ $? -eq 0 ]; then
    echo -e "  - ${GREEN}Instalasi paket berhasil!${NC}"
else
    echo -e "  - ${RED}Gagal menginstal paket via pacman. Silakan cek koneksi internet Anda.${NC}"
    exit 1
fi

# Aktifkan dan jalankan libvirtd service
echo -e "  - Mengaktifkan service virtualisasi (libvirtd)..."
echo "$PASSWORD" | sudo -S systemctl enable --now libvirtd.service
echo "$PASSWORD" | sudo -S systemctl enable --now virtlogd.socket

# Tambahkan user Anda ke grup KVM dan Libvirt agar bisa menjalankan tanpa sudo nanti
CURRENT_USER=$(whoami)
echo "$PASSWORD" | sudo -S usermod -aG kvm,libvirt "$CURRENT_USER"
echo -e "  - User ${GREEN}${CURRENT_USER}${NC} telah ditambahkan ke grup virtualisasi."

# ------------------------------------------------------------------------------
# Langkah 3: Unduh VirtIO Windows Drivers (Sangat penting untuk Windows di KVM!)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[3/5] Mengunduh VirtIO Drivers ISO untuk Windows...${NC}"
VM_DIR="$HOME/win_vm"
mkdir -p "$VM_DIR"

VIRTIO_ISO="$VM_DIR/virtio-win.iso"
if [ ! -f "$VIRTIO_ISO" ]; then
    echo -e "  - Mengunduh virtio-win.iso (Driver resmi RedHat/Fedora untuk Windows di KVM)..."
    curl -L -o "$VIRTIO_ISO" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    if [ $? -eq 0 ]; then
        echo -e "  - ${GREEN}Unduhan virtio-win.iso berhasil disimpan di ${VIRTIO_ISO}${NC}"
    else
        echo -e "  - ${RED}Gagal mengunduh VirtIO ISO. Kami akan mencobanya lagi lewat wget...${NC}"
        wget -O "$VIRTIO_ISO" "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
    fi
else
    echo -e "  - ${GREEN}virtio-win.iso sudah ada di ${VIRTIO_ISO}${NC}"
fi

# Buat Virtual Disk 100 GB (QCOW2 format dengan kompresi & dinamis)
VM_DISK="$VM_DIR/windows10.qcow2"
if [ ! -f "$VM_DISK" ]; then
    echo -e "  - Membuat virtual disk SSD 100 GB di ${VM_DISK}..."
    qemu-img create -f qcow2 "$VM_DISK" 100G
    echo -e "  - ${GREEN}Virtual disk berhasil dibuat!${NC}"
else
    echo -e "  - ${YELLOW}Virtual disk ${VM_DISK} sudah ada (lewati pembuatan disk).${NC}"
fi

# ------------------------------------------------------------------------------
# Langkah 4: Menulis Config Bersama untuk Boot Windows VM
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[4/5] Menulis config bersama agar setup dan boot tetap ketaut...${NC}"

# Hitung alokasi RAM (Gunakan 12GB dari total 24GB Anda)
RAM_ALLOCATION="12288" # 12 GB dalam MB
CPU_THREADS="8"        # Gunakan 8 threads dari 16 threads i5-12500H Anda

VM_CONFIG="$VM_DIR/vm_config.sh"
cat <<EOF > "$VM_CONFIG"
#!/usr/bin/env bash

# Shared VM configuration used by setup_kvm_windows.sh and start_win_vm.sh.
# Edit this file if you want both scripts to stay in sync.

VM_DIR="$VM_DIR"
VM_NAME="windows-vm"
VM_DISK_NAME="windows10.qcow2"
VIRTIO_ISO_NAME="virtio-win.iso"
WIN_ISO_NAME="windows.iso"
VM_DISK_SIZE="100G"
VM_RAM_MB="$RAM_ALLOCATION"
VM_SMP_SOCKETS="1"
VM_SMP_CORES="$((CPU_THREADS / 2))"
VM_SMP_THREADS="2"
VM_RDP_PORT="2222"
VM_NET_DEVICE="e1000e"
EOF

chmod +x "$VM_CONFIG"
echo -e "  - ${GREEN}Config bersama berhasil dibuat di: ${VM_CONFIG}${NC}"

START_SCRIPT="$VM_DIR/start_win_vm.sh"
if [ -f "$START_SCRIPT" ]; then
    chmod +x "$START_SCRIPT"
    echo -e "  - ${GREEN}Script boot yang sudah ada siap dipakai: ${START_SCRIPT}${NC}"
else
    echo -e "  - ${YELLOW}Script boot belum ditemukan di: ${START_SCRIPT}${NC}"
fi

# ------------------------------------------------------------------------------
# Langkah 5: Petunjuk GPU Passthrough (RTX 3050 & Intel Iris Xe)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[5/5] Membuat opsi akselerasi GPU NVIDIA RTX 3050...${NC}"

# Tulis file panduan passthrough khusus laptop hybrid
PASSTHROUGH_GUIDE="$VM_DIR/GPU_PASSTHROUGH_README.txt"
cat <<EOF > "$PASSTHROUGH_GUIDE"
==============================================================================
NVIDIA RTX 3050 GPU PASSTHROUGH FOR THE WINDOWS VM
==============================================================================

This repo now includes an automated passthrough setup for the NVIDIA RTX 3050.

Use it like this:

1. Run the setup script:
   bash gpu_passthrough_setup.sh

2. Reboot the Linux host so the GPU can bind to vfio-pci.

3. Launch the VM with passthrough:
   bash start_win_vm_gpu.sh

What this setup does:

- Detects the NVIDIA GPU and its audio function
- Writes `gpu_config.sh`
- Writes `start_win_vm_gpu.sh`
- Adds vfio and blacklist config on the host
- Regenerates initramfs and GRUB config

Notes:

- Intel Iris Xe remains the host GPU in this setup.
- The RTX 3050 is attached to the Windows guest through VFIO.
- If your external HDMI/DP output is wired to the RTX 3050, it may stop working on the host after passthrough.
- If you want the guest to use only the passthrough GPU for display, set `GPU_USE_VIRTIO_DISPLAY="no"` in `gpu_config.sh`.
- Inside Windows, install the NVIDIA driver after booting the passthrough VM.

==============================================================================
EOF

echo -e "  - ${GREEN}Dokumen panduan GPU Passthrough disimpan di: ${PASSTHROUGH_GUIDE}${NC}"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}🎉 PROSES SETUP SELESAI DENGAN SUKSES!${NC}"
echo -e "Semua kebutuhan virtualisasi KVM & QEMU telah dipersiapkan."
echo -e "Folder VM Anda berada di: ${YELLOW}${VM_DIR}${NC}"
echo -e "Silakan letakkan ISO installer Windows Anda ke ${YELLOW}${VM_DIR}/windows.iso${NC}"
echo -e "lalu jalankan salah satu script peluncur berikut:"
echo -e "${CYAN}bash ${VM_DIR}/start_win_vm.sh${NC}"
echo -e "${CYAN}bash ${VM_DIR}/gpu_passthrough_setup.sh${NC}  # lalu reboot dan jalankan start_win_vm_gpu.sh${NC}"
echo -e "${CYAN}======================================================================${NC}"
