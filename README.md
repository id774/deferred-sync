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

To install deferred-sync, execute the provided `install.sh` script:

```sh
./install.sh /opt/deferred-sync
```

By default, it installs under `/opt/deferred-sync` and places the execution script in `/etc/cron.daily/` to run automatically. If you wish to install in your home directory, run:

```sh
./install.sh ~/local/deferred-sync nosudo
```

If you want to specify an exact execution time, instead of relying on `cron.daily`, you can manually configure `cron.d` using the sample file provided in `cron/cron.d/deferred-sync`.

After installation, edit the configuration file to customize its behavior.

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

## Directory Structure

```
.
├── exec/
│   ├── deferred-sync    # Main execution script
│
├── config/
│   ├── sync.conf        # Configuration file
│   ├── exclude.conf     # List of excluded files
│
├── lib/
│   ├── load             # Plugin loader
│   ├── plugins/         # Directory containing plugins
│   │   ├── show_version
│   │   ├── get_resources
│   │   ├── get_hardware_info
│   │   ├── system_upgrade
│   │   ├── ubuntu_kernel_upgrade
│   │   ├── dump_postgresql
│   │   ├── dump_mysql
│   │   ├── dump_mongodb
│   │   ├── dump_svn
│   │   ├── incremental_backup
│   │   ├── backup_to_remote
│   │   ├── get_remote_dir
│
├── install.sh           # Installation script
│
├── cron/
│   ├── deferred-sync    # Script placed in `/etc/cron.daily/`
│   ├── cron.d/          # Sample file for custom scheduling in `/etc/cron.d/`
│
├── doc/
│   ├── VERSIONS         # Version history of the repository
```

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
