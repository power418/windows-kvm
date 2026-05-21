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
