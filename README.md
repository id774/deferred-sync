# deferred-sync

## Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Supported Operating Systems](#supported-operating-systems)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Policy](#policy)
7. [Usage Example](#usage-example)
8. [Directory Structure](#directory-structure)
9. [Contribution](#contribution)
10. [License](#license)

## Overview

deferred-sync is a backup and synchronization tool designed to periodically copy and version-control critical files while enabling remote backup capabilities. It is particularly useful for:

- Protecting configuration files and home directory data that are not managed by a version control system.
- Performing incremental backups for repository servers, databases, and file storage systems.
- Synchronizing backups across multiple VPS or cloud environments.

The tool is implemented as a shell script framework with plugin support, allowing users to extend its functionality for various tasks, such as system upgrades and database dumps.

This repository uses `master` as its primary branch name.

The name is used solely as a technical identifier, following the long-standing convention historically used by Git. It does not express or imply any association with racism, slavery, discrimination, or any political or social ideology.

## Features

- **Incremental backup with versioning**
- **Remote synchronization via `rsync` and `ssh`**, without gating the transfer on a separate connectivity probe
- **Highly extensible plugin system**
- **Support for automatic execution via `cron`**
- **Configurable exclusion of files and directories**

For a complete user-facing reference to the execution flow, plugins,
backup and synchronization behavior, configuration, installation modes,
and state-changing operations, see
[doc/FEATURES.md](doc/FEATURES.md).

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
but cron, logrotate, and backup directory setup are skipped. Give `[target_path]` as an absolute
path, since a relative path is rejected as an unknown option.

```sh
./install.sh /opt/deferred-sync   # deploys components only, no cron or logrotate setup
```

A custom target is a deployable tree: reinstalling to the same target redeploys
its `exec`, `config`, and `lib` directories, so an edited `config/` under a custom
target can be replaced as well. Standard operation that needs persistent system
configuration should use the default installation, whose configuration lives
under `/etc/opt/deferred-sync` and is not overwritten on upgrade.

When run as root, the installer performs privileged operations directly and does not
invoke `sudo`. When run as a non-root user without `nosudo`, `--no-sudo`, or `-n`, the
installer uses `sudo` for those operations.

Specifying `nosudo`, `--no-sudo`, or `-n` runs the installer without `sudo` and skips the
recursive ownership change of the target directory. If you wish to install in your home
directory, run:

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

## Policy

deferred-sync maintains a self-contained implementation and maintenance policy covering compatibility, safety, unattended execution, plugin behavior, configuration, logging, installation, and validation. It is stated in [doc/POLICY.md](doc/POLICY.md), which is where these rules are maintained.

What matters before writing or enabling a plugin:

- **A plugin is sourced, not executed.** It returns instead of exiting, keeps a `cd` inside a subshell, and owns the variable names it sets. See [The Contract Between the Core and a Plugin](doc/POLICY.md#3-the-contract-between-the-core-and-a-plugin).
- **Independent task failures do not abort an established run.** `lib/load`
  reports a failing plugin as `[WARN]`, keeps the first nonzero status, and
  runs the rest. Required setup failures may stop the run as described in
  [Warn and Continue](doc/POLICY.md#32-warn-and-continue).
- **Return codes** are `0` success, `1` command failure or resource missing, `2` network unreachable, `3` local prerequisite missing; documented components may propagate an external command status where their component contract says so. See [Return Codes](doc/POLICY.md#33-return-codes).
- **A missing prerequisite is skipped, never created**, so that a failed mount cannot become a backup written to the wrong disk. See [Safety](doc/POLICY.md#4-safety).
- **Log output** uses `[INFO]`, `[WARN]`, and `[ERROR]`, and stamps each phase with the time, because the log is read hours after the run. See [Logging](doc/POLICY.md#6-logging).

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

## Directory Structure

This section describes the main directories of the repository and what each one
is for. It is not a complete file listing: only the entries worth knowing about
before configuring a run or writing a plugin are shown.

```
.
├── exec/
│   └── deferred-sync         Main execution script. The entry point cron invokes.
├── config/                   Deployed to /etc/opt/deferred-sync/ and edited there.
│   ├── sync.conf             All settings for a run (see Configuration).
│   └── exclude.conf          Patterns excluded from the backup.
├── lib/                      Everything the main script sources at run time.
│   ├── load                  Plugin loader. Runs each plugin and applies warn-and-continue.
│   ├── before                Default STARTSCRIPT, run before synchronization.
│   ├── after                 Default ENDSCRIPT, run after synchronization.
│   └── plugins/              One file per task, run in filename order.
├── install.sh                Installer and uninstaller.
├── cron/                     Scheduling and log rotation samples, installed on Linux.
│   ├── deferred-sync         Placed in /etc/cron.daily/.
│   ├── cron.d/               Sample for a fixed execution time, for /etc/cron.d/.
│   └── logrotate.d/          Log rotation config, for /etc/logrotate.d/.
└── doc/
    ├── FEATURES.md           User-facing feature and behavior reference.
    ├── POLICY.md             Implementation policy for this repository.
    ├── VERSIONS              Version history of the repository.
    ├── LICENSE.md            License notice.
    ├── COPYING               GPL version 3 text.
    └── COPYING.LESSER        LGPL version 3 text.
```

The split between `exec/`, `config/` and `lib/` is what the installer deploys:
`exec/` is the one thing cron calls, `config/` is the only part meant to be
edited on a host, and `lib/` is the code that `sync.conf` selects between. A
change in behavior is normally a change in `config/`, not in the other two.

`lib/plugins/` is where the work actually happens, and each file is one task.
The current plugin catalogue, including plugin filenames, roles, and main
side effects, is maintained in
[doc/FEATURES.md](doc/FEATURES.md#5-plugin-catalog).
The README deliberately does not duplicate that inventory.

Plugins run in filename order; the numeric prefix controls that order and may be
omitted in `PLUGINS`, since each entry is matched against the end of the plugin
filename (for example, `get_resources` matches `10_get_resources`). Each plugin
file has one clear operational responsibility. A change that belongs to an
existing responsibility stays in that plugin. An independent new operational
task uses a new plugin file, with its numeric prefix chosen from the
operational and data-flow order in which the task must run, following the
[plugin contract](doc/POLICY.md#3-the-contract-between-the-core-and-a-plugin).

## Contribution

We welcome contributions! Here's how you can help:
1. Fork the repository.
2. Add or improve a feature, or fix an issue.
3. Submit a pull request with clear documentation and changes.

Please ensure your code is well-structured and documented, and follow
[doc/POLICY.md](doc/POLICY.md). Everything under `lib/` is sourced by a root
shell that cron starts unattended, so that document asks new code there to
destroy nothing it was not asked to touch, to let the job continue when it
fails, and to leave a log that answers the question the next morning.

## License

This repository is dual licensed under the [GPL version 3](https://www.gnu.org/licenses/gpl-3.0.html) or the [LGPL version 3](https://www.gnu.org/licenses/lgpl-3.0.html), at your option.
For full details, please refer to the [LICENSE](doc/LICENSE.md) file.  See also [COPYING](doc/COPYING) and [COPYING.LESSER](doc/COPYING.LESSER) for the complete license texts.

Thank you for using and contributing to this repository!
