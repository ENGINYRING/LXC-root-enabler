[![ENGINYRING](https://cdn.enginyring.com/img/logo_dark.png)](https://www.enginyring.com)

# LXC Template SSH root Login Enabler

This script automates the process of modifying Proxmox LXC container templates stored in `/var/lib/vz/template/cache`. It ensures that each template has SSH installed and configured to allow root login and password authentication.

---

## Features

- Supports `.tar.gz` and `.tar.xz` LXC template archives.
- Extracts templates, installs `openssh-server` if missing.
- Edits `/etc/ssh/sshd_config` inside the template to:
  - Set `PermitRootLogin yes`
  - Set `PasswordAuthentication yes`
- Repackages the template archive.
- Keeps track of already processed templates to avoid duplicate work.
- Handles DNS resolution inside chroot by binding `/etc/resolv.conf`.
- Works with AlmaLinux, Rocky Linux, CentOS, Debian, Ubuntu templates (detects package manager automatically).

---

## Usage

1. Place the script on your Proxmox host.
2. Make it executable:

   ```bash
   chmod +x templateroot.sh
   ```

3. Run the script as root or with sudo:

   ```bash
   sudo ./templateroot.sh
   ```

4. The script will process all LXC templates in `/var/lib/vz/template/cache`.

---

## Notes

- The script modifies templates **in place**; backups of original templates are recommended before running.
- The script requires network access for the chroot environment to install packages.
- The script creates a log file at `/var/lib/vz/template/edited_templates.log` to track processed templates.
- You can reset the log by deleting this file if you want to reprocess templates.
- Tested with common Enterprise Linux and Debian-based LXC templates.

---

## License

MIT License (free to use and modify)

---

If you want improvements or help with integration, just open an issue or contact us.
