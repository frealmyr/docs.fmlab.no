# Lenovo X1 Carbon Gen 9

## Intel Graphics

The iGPU is gen 12, which has new features called `GuC` and `HuC` built-in that have power usage and performance benefits. When enabled, my laptop runs cooler, gained 3-4 hours of battery with the same usage pattern, hardware acceleration also seems to work better in firefox/chromium.

These features are not enabled by default, as the official intel docs states that they are not available on `< gen12` intel CPUs. However, this laptop have a gen11 CPU, while the iGPU is gen12 and the features works properly when enabled.

There is currently a mailing list for enabling these features by default for this CPU. https://wiki.archlinux.org/title/Talk:Intel_graphics#TGL/RKL_GuC_Submission

All credit to inslee@askfedora: https://ask.fedoraproject.org/t/intel-graphics-best-practices-and-settings-for-hardware-acceleration/21119
