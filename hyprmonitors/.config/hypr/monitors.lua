-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all
--
-- Ported from the Omarchy 3 monitors.conf during the Omarchy 4 (quattro) upgrade,
-- 2026-08-18. The upgrade dropped a stock monitors.lua in place and the whole
-- layout reverted to `preferred,auto,auto` (flat row, DP-4 at 60Hz, no rotation,
-- no VRR). This restores it.

-- Straight 1x setup for these 1080p panels — NOT the retina 2x default the
-- stock quattro monitors.lua ships with (that shipped GDK_SCALE=2, which
-- doubles every GTK app on this box).
hl.env("GDK_SCALE", "1")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- === 5-monitor layout (physical) ===
--   Top row (y=0):   HDMI-A-2 (Acer)  |  DP-4 ASUS 240Hz  |  DP-3 (Acer)
--   Main (y=1080):   HDMI-A-1 portrait (far left)  +  DP-2 ultrawide (ASUS centered over it)
-- Acers by serial: HDMI-A-1=0x93923822(portrait)  HDMI-A-2=0x050161D6(top-L)  DP-3=0x93923FDF(top-R)

-- Portrait Acer — far left, rotated 90°, bottom-aligned with the ultrawide
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "0x240",     scale = 1, transform = 1 })

-- Top row, left → right
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@144", position = "1080x0",    scale = 1 })
hl.monitor({ output = "DP-4",     mode = "1920x1080@240", position = "3000x0",    scale = 1 })
hl.monitor({ output = "DP-3",     mode = "1920x1080@144", position = "4920x0",    scale = 1 })

-- 49" Samsung ultrawide — main level, 144Hz + fullscreen VRR (the gaming screen)
hl.monitor({ output = "DP-2",     mode = "3840x1080@144", position = "2040x1080", scale = 1, vrr = 2 })

-- DP-4 (ASUS) rides the Intel iGPU: its hardware G-Sync module won't run on the open NVIDIA
-- driver, and the 3080 caps at 4 displays. iGPU drives it at 240Hz; compositing stays on NVIDIA.
-- Failsafe: high refresh on the iGPU output sometimes comes up at 60 on a fresh modeset, so
-- re-assert 240Hz a few seconds after login. (Was an exec-once in autostart.conf pre-quattro.)
-- NB: `hyprctl keyword` is REJECTED under the Lua parser ("keyword can't work with
-- non-legacy parsers. Use eval.") — it fails silently from a background shell, so the
-- failsafe must go through `hyprctl eval` with an hl.monitor() call.
o.exec_on_start(
  "sleep 3 && hyprctl eval 'hl.monitor({ output = \"DP-4\", mode = \"1920x1080@240\", position = \"3000x0\", scale = 1 })'"
)
