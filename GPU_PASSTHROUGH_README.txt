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
- Writes 
- Writes [10:36:20] Memulai Windows VM dengan NVIDIA passthrough
[10:36:20]   - VM name: windows-vm
[10:36:20]   - GPU: NVIDIA RTX 3050 Mobile (0000:01:00.0)
[10:36:20]   - Audio GPU: 0000:01:00.1
[10:36:20]   - CPU: 8 vCPUs
[10:36:20]   - RAM: 12288 MB
[10:36:20] OK   Virtual disk ditemukan: /home/ahmadzanisy/win_vm/windows10.qcow2
[10:36:20] OK   ISO Windows ditemukan: /home/ahmadzanisy/win_vm/windows.iso
[10:36:20] OK   VirtIO ISO ditemukan: /home/ahmadzanisy/win_vm/virtio-win.iso
[10:36:20] OK   Host GPU device ditemukan: 0000:01:00.0
[10:36:20] OK   Host audio device ditemukan: 0000:01:00.1
[10:36:20] WARN GPU driver aktif: nvidia
[10:36:20] FAIL GPU masih terikat ke driver 'nvidia'.
[10:36:20] WARN Audio driver aktif: snd_hda_intel
[10:36:20] FAIL Audio function belum bind ke vfio-pci.
[10:36:20] FAIL GPU tidak punya iommu_group.
[10:36:20] FAIL Audio device tidak punya iommu_group.
[10:36:20] Passthrough belum siap.
[10:36:20] Pastikan IOMMU aktif di BIOS/UEFI dan host sudah dibind ke vfio-pci.
[10:36:20] Kalau baru ubah setup, jalankan gpu_passthrough_setup.sh lalu reboot host.
- Adds vfio and blacklist config on the host
- Regenerates initramfs and GRUB config

Notes:

- Intel Iris Xe remains the host GPU in this setup.
- The RTX 3050 is attached to the Windows guest through VFIO.
- If your external HDMI/DP output is wired to the RTX 3050, it may stop working on the host after passthrough.
- If you want the guest to use only the passthrough GPU for display, set  in .
- Inside Windows, install the NVIDIA driver after booting the passthrough VM.

==============================================================================
