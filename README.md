# Windows 10 VM QEMU/KVM + GPU Passthrough

Repo ini menyiapkan Windows 10 VM di Linux host pakai QEMU/KVM. Ada dua mode yang perlu dibedakan:

- Mode normal: VM jalan pakai display virtio, cocok untuk install dan test awal.
- Mode GPU passthrough: GPU fisik NVIDIA RTX 3050 dipindahkan ke Windows guest supaya Windows bisa install driver NVIDIA asli.

## File Penting

- `setup_kvm_windows.sh`: install dependency, download VirtIO ISO, buat disk qcow2, dan tulis config bersama.
- `start_win_vm.sh`: boot Windows VM.
- `gpu_passthrough_setup.sh`: setup host untuk NVIDIA RTX passthrough dan generate launcher GPU.
- `start_win_vm_gpu.sh`: boot Windows VM dengan NVIDIA RTX passthrough.
- `vm_config.sh`: satu sumber config untuk setup dan boot.
- `gpu_config.sh`: config khusus GPU passthrough.
- `GPU_PASSTHROUGH_README.txt`: panduan VFIO/passthrough yang lebih detail.
- `windows.iso`: installer Windows 10/11 yang harus kamu taruh di folder ini.
- `virtio-win.iso`: driver VirtIO untuk Windows guest.
- `windows10.qcow2`: disk VM, dibuat otomatis kalau belum ada.

## Hardware Host

Setup ini dibuat untuk laptop hybrid:

- Intel Iris Xe dipakai oleh Linux host.
- NVIDIA RTX 3050 Mobile dipakai untuk passthrough ke Windows guest.

Contoh device yang biasanya muncul:

- Intel iGPU: `00:02.0`
- NVIDIA GPU: `01:00.0`
- NVIDIA Audio: `01:00.1`

## Prasyarat

- Linux host sudah support KVM.
- Virtualisasi CPU aktif di BIOS/UEFI.
- Kalau mau GPU passthrough, IOMMU juga harus aktif.
- File ISO Windows sudah ada sebagai `windows.iso`.
- Repo ini diasumsikan ada di `~/win_vm`.

## Quick Start

1. Masuk ke folder repo.

```bash
cd ~/win_vm
```

2. Pastikan script bisa dieksekusi.

```bash
chmod +x setup_kvm_windows.sh start_win_vm.sh gpu_passthrough_setup.sh start_win_vm_gpu.sh
```

3. Buka `setup_kvm_windows.sh` dan ganti variabel `PASSWORD` dengan password sudo kamu sendiri.

4. Jalankan setup sekali saja.

```bash
bash setup_kvm_windows.sh
```

5. Letakkan installer Windows di `~/win_vm/windows.iso` kalau belum ada.

6. Jalankan VM.

```bash
bash start_win_vm.sh
```

7. Kalau mau NVIDIA passthrough, jalankan setup GPU lalu reboot host.

```bash
bash gpu_passthrough_setup.sh
```

8. Setelah reboot, jalankan VM GPU.

```bash
bash start_win_vm_gpu.sh
```

## Install Windows

- Disk VM dibuat sebagai `qcow2` 100G.
- Storage sekarang dipasang lewat SATA/AHCI supaya Windows installer langsung melihat disk.
- Network default sekarang pakai `e1000e` supaya Windows langsung mengenali adapter tanpa driver tambahan.
- Kalau nanti mau performa network lebih bagus, kamu bisa ganti `VM_NET_DEVICE` ke `virtio-net-pci` setelah driver VirtIO network dipasang.
- Kalau diminta driver tambahan saat instalasi, gunakan `virtio-win.iso`.
- Setelah Windows selesai terpasang, kamu bisa install VirtIO driver untuk network dan komponen lain.

## Akses VM

- Display default memakai `virtio`.
- RDP host forward tersedia dari port `2222` di host ke port `3389` di guest.
- Kalau kamu pakai Linux host, sambungkan pakai Remmina atau client RDP lain ke `127.0.0.1:2222`.

## GPU Passthrough

Kalau tujuanmu adalah Windows guest benar-benar memakai RTX 3050 fisik, kamu perlu VFIO passthrough. Itu beda dengan sekadar deteksi GPU.

Setup otomatis yang ada di repo ini sekarang fokus ke NVIDIA RTX 3050.

Urutan umumnya:

1. Aktifkan `intel_iommu=on iommu=pt` di kernel command line.
2. Reboot host.
3. Pastikan GPU NVIDIA dan audio function-nya terdeteksi.
4. Bind `01:00.0` dan `01:00.1` ke VFIO atau tambahkan sebagai `PCI Host Device` di Virt-Manager.
5. Boot VM.
6. Install driver NVIDIA di dalam Windows guest.

Kalau mau langkah lengkap, buka:

- `GPU_PASSTHROUGH_README.txt`

## Mode Yang Dipakai Script Sekarang

Saat ini `start_win_vm.sh` masih menjalankan:

- disk lewat SATA/AHCI supaya installer Windows langsung lihat storage
- display virtual `virtio`
- network `e1000e` secara default supaya langsung kedetect

Artinya:

- Windows guest akan jalan normal untuk install dan test.
- Windows guest belum otomatis memakai RTX 3050 fisik sampai kamu aktifkan passthrough VFIO.
- Setelah Windows selesai terpasang dan driver VirtIO network sudah ada, kamu bisa ubah `VM_NET_DEVICE` kembali ke `virtio-net-pci`.

Kalau kamu menjalankan `start_win_vm_gpu.sh`, guest akan tetap punya display virtio sebagai fallback, tapi RTX 3050 ikut di-attach lewat VFIO.

## Ubah Config

Kalau mau ubah resource VM, edit `vm_config.sh`.

Nilai yang paling sering diubah:

- `VM_RAM_MB`
- `VM_SMP_CORES`
- `VM_SMP_THREADS`
- `VM_DISK_SIZE`
- `VM_RDP_PORT`
- `VM_NET_DEVICE`

Contoh:

```bash
VM_RAM_MB="16384"
VM_SMP_CORES="6"
VM_SMP_THREADS="2"
VM_NET_DEVICE="e1000e"
```

## Troubleshooting

- Kalau setup gagal di bagian sudo, cek lagi `PASSWORD` di `setup_kvm_windows.sh`.
- Kalau disk tidak muncul saat install Windows, pastikan kamu pakai `start_win_vm.sh` versi terbaru dari repo ini.
- Kalau guest belum pakai RTX, itu normal kalau passthrough belum dikonfigurasi.
- Kalau kamu belum reboot setelah `gpu_passthrough_setup.sh`, passthrough belum aktif.
- Kalau RDP tidak nyambung, pastikan port `2222` belum dipakai aplikasi lain.

## Catatan

- `vm_config.sh` adalah sumber config bersama supaya setup dan boot tetap sinkron.
- `setup_kvm_windows.sh` akan menulis ulang `vm_config.sh` saat dijalankan.
- `gpu_passthrough_setup.sh` akan menulis ulang `gpu_config.sh` dan `start_win_vm_gpu.sh`.
- Intel Iris Xe tetap dipakai host pada setup ini.
- Kalau kamu mau output fisik langsung dari RTX, ubah `GPU_USE_VIRTIO_DISPLAY="no"` di `gpu_config.sh` dan sambungkan monitor ke port GPU yang memang aktif di host.
