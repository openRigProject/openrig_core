# openrig_core

Shared pure Dart package used by openRigConsole and openRigMobile. Provides rig control clients, ADIF logging, DX cluster, mDNS discovery, grid utilities, and more.

> **PRE-RELEASE SOFTWARE — EXPERIMENTAL USE ONLY**
>
> This project is pre-release software. It has not been tested for security, reliability, or fitness for any particular purpose. Use it only for experimentation and personal learning. It is **not** suitable for production or safety-critical use.
>
> By using this software you agree that the author(s) shall not be held liable for any damages, data loss, security incidents, regulatory violations, or any other harm arising from its use.

## Key Modules

- `rig_client.dart` — abstract rig control interface
- `rigctld_client.dart` — TCP client for hamlib `rigctld`
- `hamlib_ffi_client.dart` — direct FFI bindings to `libhamlib`
- `dx_cluster_client.dart` — Telnet DX cluster client
- `adif.dart` — ADIF log read/write
- `mdns_discovery.dart` — mDNS/DNS-SD discovery for openRig devices
- `band_plan.dart` — HF and VHF/UHF band plan
- `grid_utils.dart` — Maidenhead grid square utilities

## Testing

```bash
dart test
```
