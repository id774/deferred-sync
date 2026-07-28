# deferred-sync

## Overview

deferred-sync is a backup and synchronization tool designed to periodically copy and version-control critical files while enabling remote backup capabilities. It is particularly useful for:

- Protecting configuration files and home directory data that are not managed by a version control system.
- Performing incremental backups for repository servers, databases, and file storage systems.
- Synchronizing backups across multiple VPS or cloud environments.

The tool is implemented as a shell script framework with plugin support, allowing users to extend its functionality for various tasks, such as system upgrades and database dumps.

## Features

- **Incremental backup with versioning**
- **Remote synchronization via `rsync` and `ssh`**
- **Highly extensible plugin system**
- **Support for automatic execution via `cron`**
- **Configurable exclusion of files and directories**

## Supported Operating Systems

deferred-sync is designed to run on the following UNIX-like operating systems:

- **Red Hat Enterprise Linux 5 and later**
- **CentOS 5 and later**
- **Scientific Linux 5 and later**
- **Debian GNU/Linux 5 and later**
- **Ubuntu 8.04 LTS and later**
- **Solaris 10 and later**
- **Mac OS X 10.5 and later**

Some plugins may not be compatible with Solaris and macOS.

## Installation

For a standard system-wide installation, run the provided `install.sh` script without arguments:

```sh
./install.sh
```

This installs under `/opt/deferred-sync` and additionally sets up:

- `/etc/cron.daily/deferred-sync` (skipped if `/etc/cron.d/deferred-sync` already exists)
- `/etc/logrotate.d/deferred-sync`
- the default backup directories `/home/backup` and `/home/remote`

These steps run only on Linux, and only when no `[target_path]` is given. Passing an explicit
`[target_path]` is treated as a custom installation: the components are deployed to that path,
but cron, logrotate, and backup directory setup are skipped.

```sh
./install.sh /opt/deferred-sync   # deploys components only, no cron or logrotate setup
```

Specifying `nosudo` runs the installer without `sudo` and skips the recursive ownership change
of the target directory. If you wish to install in your home directory, run:

```sh
./install.sh ~/local/deferred-sync nosudo
```

You can optionally add the `--link` flag to create symlinks in `/etc/cron.config/` and `/etc/cron.exec/`:

```sh
./install.sh --link
```

The `/etc/cron.exec/deferred-sync` symlink always points at `/opt/deferred-sync/exec/deferred-sync`,
so `--link` is intended for the default installation path.

If you want to specify an exact execution time, instead of relying on `cron.daily`, you can manually configure `cron.d` using the sample file provided in `cron/cron.d/deferred-sync`.

After installation, edit the configuration file to customize its behavior.

### Uninstallation

To uninstall a system-wide installation (default `/opt/deferred-sync`), run:

```sh
sudo ./install.sh --uninstall
```

This will remove all files installed by deferred-sync **except** the log directory (`/var/log/deferred-sync`).

For safety, `--uninstall` removes only `/opt/deferred-sync` as the installation target.
Custom installation targets are not removed automatically.

## Configuration

The main configuration file is `config/sync.conf`. It defines all parameters required for operation, including:

- `DRY_RUN` - Enables dry-run mode if set to `true`.
- `EXCLUDEFILE` - Specifies files or patterns to be excluded.
- `JOBLOG` - Defines the log file location.
- `STARTSCRIPT` - A script to run before the synchronization process.
- `ENDSCRIPT` - A script to run after the synchronization process.
- `ADMIN_MAIL_ADDRESS` - Email to receive job completion notifications.
- `LOAD_PLUGINS_ALL` - If `true`, all plugins will be loaded automatically.
- `PLUGINS` - List of plugins to load selectively.

### Optional System-Wide Configuration Symlinks

If you pass the `--link` option during installation, deferred-sync will automatically create symlinks:

- `/etc/cron.config/sync.conf` → `/etc/opt/deferred-sync/sync.conf`
- `/etc/cron.config/exclude.conf` → `/etc/opt/deferred-sync/exclude.conf`
- `/etc/cron.exec/deferred-sync` → `/opt/deferred-sync/exec/deferred-sync`

This is useful when integrating with a centralized cron execution and configuration framework.

## Directory Structure

```
.
├── exec/
│   └── deferred-sync         # Main execution script
│
├── config/
│   ├── sync.conf             # Configuration file
│   └── exclude.conf          # List of excluded files
│
├── lib/
│   ├── load                  # Plugin loader
│   ├── before                # Default STARTSCRIPT (pre-sync hook)
│   ├── after                 # Default ENDSCRIPT (post-sync hook)
│   └── plugins/              # Directory containing plugins
│       ├── 09_show_version
│       ├── 10_get_resources
│       ├── 11_server_alive_check
│       ├── 15_get_hardware_info
│       ├── 20_system_upgrade
│       ├── 25_ubuntu_kernel_upgrade
│       ├── 30_dump_mysql
│       ├── 31_dump_postgresql
│       ├── 32_dump_mongodb
│       ├── 35_dump_svn
│       ├── 70_incremental_backup
│       ├── 80_backup_to_remote
│       └── 85_get_remote_dir
│
├── install.sh                # Installation script
│
├── cron/
│   ├── deferred-sync         # Script placed in `/etc/cron.daily/`
│   ├── cron.d/               # Sample file for custom scheduling in `/etc/cron.d/`
│   └── logrotate.d/          # Log rotation config for `/etc/logrotate.d/`
│
└── doc/
    ├── VERSIONS              # Version history of the repository
    ├── LICENSE               # License notice
    ├── COPYING               # GPL version 3 text
    └── COPYING.LESSER        # LGPL version 3 text
```

Plugins are executed in filename order. The numeric prefix controls that order and may be
omitted in `PLUGINS`, since each entry is matched against the end of the plugin filename
(for example, `get_resources` matches `10_get_resources`).

## Policy

deferred-sync adheres to a strict, POSIX-compliant policy for error handling, return codes, and plugin design.

### Plugin Behavior Policy

Each plugin must:
- **Never exit directly.** Always use `return` to propagate status to the parent process.
- **Log results explicitly** using `[INFO]`, `[WARN]`, or `[ERROR]` prefixes.
- **Return appropriate codes** based on the nature of the failure.
- **Avoid side effects** (e.g., `mkdir`, file creation) when prerequisites are missing.
- **Report missing environments** (such as `PGDUMP` or `BACKUPTO`) using `return 3`.
- **Contain shell state changes.** Plugins are sourced into the calling shell, so a change of
  working directory must be confined to a subshell to avoid affecting later plugins.

### Core Loader Policy

The core `lib/load` script:
- Sequentially loads all enabled plugins.
- Records the first nonzero plugin status in `FAILED_STATUS`.
- Does **not** terminate the overall execution on plugin error.
- Logs a `[WARN]` message and continues loading subsequent plugins.

This ensures that critical backup, dump, and synchronization tasks can continue even when individual modules encounter errors.

### Logging Policy

All outputs must use standardized log levels:

- `[INFO]` — Normal operations (start, completion, status)
- `[WARN]` — Recoverable issues (skipped operations, missing directories)
- `[ERROR]` — Fatal or unrecoverable issues (e.g., broken configuration)

These messages are designed for easy parsing by monitoring systems and cron logs.

### Return Code Convention

All core components and plugins follow the same standardized return code convention:

| Code | Meaning | Typical Case |
|:----:|:---------|:--------------|
| **0** | Success | Operation completed successfully |
| **1** | Command failure or resource missing | Command execution error, missing database, or permission failure |
| **2** | Network unreachable | Remote host unreachable, failed ping, or SSH connection error |
| **3** | Local prerequisite missing | Local directory or configuration not found, environment not initialized |

This convention ensures consistent behavior across all plugins and allows the core loader (`lib/load`) to apply a **warn-and-continue** policy for nonzero return values.

Plugins that merely wrap an external command propagate that command's exit status instead, so
values outside this table can appear in the log:

- `11_server_alive_check` follows the POSIX shell convention and returns `127` when the target
  script does not exist and `126` when it exists but is not executable. Otherwise it returns the
  exit status of the invoked script.
- `20_system_upgrade` and `25_ubuntu_kernel_upgrade` return the exit status of the underlying
  package manager (`apt-get`, `yum`, or `package-cleanup`).

The warn-and-continue policy of `lib/load` applies to these values in the same way.

## Usage Example

Set up `cron` to execute deferred-sync periodically. This ensures that all protected files and directories are backed up regularly.

### **Example: Daily Backup and Remote Sync**

- **Primary environment (Data Center):**
  - Backs up critical files daily
  - Synchronizes them to a remote server

- **Remote Backup Server (Different Location):**
  - Stores historical versions of backups
  - Allows recovery in case of failures

```
+----------------------+
|  Production Server  |  (Data Center)
+----------------------+
           |
           | cron executes deferred-sync daily
           |
+----------------------+
|  Backup Server      |  (Remote Location)
+----------------------+
```

## Contribution

We welcome contributions! Here's how you can help:
1. Fork the repository.
2. Add or improve a feature, or fix an issue.
3. Submit a pull request with clear documentation and changes.

Please ensure your code is well-structured and documented.

## License

This repository is dual licensed under the [GPL version 3](https://www.gnu.org/licenses/gpl-3.0.html) or the [LGPL version 3](https://www.gnu.org/licenses/lgpl-3.0.html), at your option.
For full details, please refer to the [LICENSE](doc/LICENSE) file.  See also [COPYING](doc/COPYING) and [COPYING.LESSER](doc/COPYING.LESSER) for the complete license texts.

Thank you for using and contributing to this repository!
