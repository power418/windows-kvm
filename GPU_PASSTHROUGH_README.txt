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
- Writes Peringatan: 0000:01:00.0 masih terikat ke driver 'nvidia'.
Passthrough akan gagal sampai GPU dibind ke vfio-pci dan host di-reboot.
Memulai Windows VM dengan NVIDIA passthrough...
  - GPU: NVIDIA RTX 3050 Mobile (0000:01:00.0)
  - Audio GPU: 0000:01:00.1
  - CPU: 8 vCPUs
  - RAM: 12288 MB
- Adds vfio and blacklist config on the host
- Regenerates initramfs and GRUB config

Notes:

- Intel Iris Xe remains the host GPU in this setup.
- The RTX 3050 is attached to the Windows guest through VFIO.
- If your external HDMI/DP output is wired to the RTX 3050, it may stop working on the host after passthrough.
- If you want the guest to use only the passthrough GPU for display, set  in .
- Inside Windows, install the NVIDIA driver after booting the passthrough VM.

==============================================================================
