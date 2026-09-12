# deferred-sync Feature Reference

This document provides a user-facing reference for the features provided by deferred-sync and shows which component implements each capability.

deferred-sync is not just an rsync wrapper.

It is a backup and synchronization framework that runs multiple configured plugins in sequence and can perform system inspection, system upgrades, database dumps, SVN dumps, versioned local backups, remote backup, and remote directory retrieval as one unattended job.

The README explains the project overview, installation, basic configuration, and directory layout.

`doc/POLICY.md` defines the implementation policy, plugin contract, safety rules, return codes, and logging conventions.

The implementation is the primary evidence of what each component currently does, while the component header records its local operational contract and this document records the intended user-facing behavior. A mismatch is resolved by comparing the implementation, documented interface, history, and maintenance intent rather than by treating an accidental implementation detail as the specification.

This `FEATURES.md` sits between those layers.

Its purpose is to make it possible to answer the following questions without reading every source file individually:

- What can deferred-sync do?
- Which plugin performs a particular task?
- Which operations can modify or delete data?
- Which configuration controls each capability?

## 1. Overall Structure

deferred-sync is organized into the following layers.

| Layer | Role | Main contents |
| --- | --- | --- |
| `exec/` | Execution entry point | Main `deferred-sync` executable |
| `config/` | Runtime configuration | Plugin selection, backup sources and destinations, remote hosts, database settings, and related values |
| `lib/load` | Plugin loader | Selects plugins, runs them in sequence, and aggregates failure status |
| `lib/before` | Pre-run hook | Default example of work run before plugins |
| `lib/after` | Post-run hook | Default example of work run after plugins |
| `lib/plugins/` | Operational tasks | Reporting, upgrades, dumps, backups, and remote synchronization |
| `cron/` | Unattended execution | Cron and logrotate deployment assets |
| `install.sh` | Installation | Deploys components, configuration, cron, logrotate, and related system integration |
| `doc/` | Documentation | Policy, version history, licenses, and feature reference |

## 2. What Happens During One Run

The basic execution sequence is:

    configuration load
        ↓
    STARTSCRIPT
        ↓
    plugin loader
        ↓
    enabled plugins
        ↓
    ENDSCRIPT
        ↓
    completion log
        ↓
    optional administrator mail

`STARTSCRIPT`, the plugin loader, and `ENDSCRIPT` run sequentially.

If one of these phases returns a nonzero status, deferred-sync records a warning and continues to the next phase instead of aborting the whole job immediately.

If `STARTSCRIPT` or `ENDSCRIPT` is configured but is not a readable regular file, deferred-sync records a warning and continues to the next phase without sourcing it. This is not unconditional continuation: a setup prerequisite failure that prevents the run from being established, such as an unreadable configuration file, can stop execution before this sequence begins.

This behavior is intended for unattended backup jobs, where failure of one auxiliary task should not automatically prevent all remaining backup work from running.

## 3. Plugin Execution

Plugins are sourced into the current shell by `lib/load`; they are not executed as independent child processes.

Plugin selection has two modes.

| Setting | Behavior |
| --- | --- |
| `LOAD_PLUGINS_ALL=true` | Loads every available plugin in `lib/plugins/` |
| `LOAD_PLUGINS_ALL=false` | Loads only the plugins listed in `PLUGINS` |

The repository configuration currently uses:

    LOAD_PLUGINS_ALL=false

and the default `PLUGINS` list is:

    get_resources
    incremental_backup

Therefore, the presence of a plugin in the repository does not by itself mean that the feature runs automatically.

System upgrades, database dumps, remote synchronization, and other optional capabilities run only when selected by configuration.

When `LOAD_PLUGINS_ALL=false`, each `PLUGINS` entry is matched against the end of a plugin filename, and the numeric prefix may be omitted (for example, `get_resources` matches `10_get_resources`). A selector must resolve to exactly one readable plugin file to be sourced. If a selector matches no readable plugin, or matches more than one, the loader reports a `[WARN]` and treats it as a local prerequisite failure (status `3`) instead of running any of the ambiguous candidates. Processing continues with the remaining selectors either way.

## 4. Plugin Order

The numeric prefix in a plugin filename controls execution order.

The current ordering bands are:

| Number range | Category | Purpose |
| --- | --- | --- |
| 09–15 | Reporting and inspection | Collect software, system resource, server availability, and hardware information |
| 20–25 | System maintenance | Update operating-system packages and kernels |
| 30–35 | Data dumps | Create MySQL, PostgreSQL, MongoDB, and SVN dumps |
| 70 | Local backup | Create the local incremental backup |
| 80–85 | Remote synchronization | Push backups to remote hosts or retrieve remote backup data |

This ordering is meaningful.

Database and repository dumps run before the local incremental backup so that newly created dumps can be included in the same backup run.

The local backup runs before remote transfer so that remote synchronization uses the completed local backup state.

## 5. Plugin Catalog

The current plugin catalog is shown below.

| Plugin | Category | Main capability | Main output or side effect |
| --- | --- | --- | --- |
| `09_show_version` | Reporting | Retrieve software versions | Logs versions of Ruby, Python, Java, Go, MongoDB, and Protocol Buffers when present |
| `10_get_resources` | Reporting | Retrieve system resources | Logs kernel, distribution, uptime, memory, disk, block-device, LVM, and network information |
| `11_server_alive_check` | Monitoring | Run an external server-alive check | Executes the configured check script and propagates its status |
| `15_get_hardware_info` | Reporting | Retrieve hardware, DNS, and SMART information | Logs DMI, PCI, power, DNS, and disk SMART information when corresponding tools are available |
| `20_system_upgrade` | Maintenance | Upgrade operating-system packages | Runs APT or YUM maintenance, optional old-kernel cleanup, and `freshclam` when available |
| `25_ubuntu_kernel_upgrade` | Maintenance | Upgrade Ubuntu kernels | Purges old kernel packages and installs the configured Ubuntu kernel packages |
| `30_dump_mysql` | Dump | Dump MySQL databases | Creates one compressed `.sql.gz` file per configured database |
| `31_dump_postgresql` | Dump | Dump a PostgreSQL cluster | Creates `all.dump.gz` |
| `32_dump_mongodb` | Dump | Dump MongoDB data | Creates the configured ZIP archive from a temporary dump tree |
| `35_dump_svn` | Dump | Dump SVN repositories | Creates one ZIP dump per configured repository |
| `70_incremental_backup` | Backup | Perform rsync-based incremental backup | Maintains the current mirror and dated backup directories |
| `80_backup_to_remote` | Remote synchronization | Copy local backups to remote hosts | Mirrors backup data to remote hosts over SSH and rsync |
| `85_get_remote_dir` | Remote synchronization | Retrieve remote directories | Synchronizes configured remote directories into local host-specific destinations |

## 6. Reporting and System Inspection

### 6.1 `09_show_version`

`09_show_version` reports versions of major software installed under expected `/opt/<software>/current/bin/` paths.

The current targets are:

- Ruby
- Python
- Java
- Go
- MongoDB
- Protocol Buffers

If the corresponding executable does not exist, that software is skipped.

### 6.2 `10_get_resources`

`10_get_resources` records the current system state.

Its output can include:

- Kernel information
- Distribution information
- Debian version
- Uptime
- Memory usage
- Filesystem usage
- Block-device mapping
- Filesystem mapping
- LVM logical-volume mapping
- Network-interface status

Additional information is collected when commands such as `lsb_release`, `lsblk`, `lvs`, and `ip` are available.

### 6.3 `11_server_alive_check`

By default, `11_server_alive_check` targets:

    /etc/cron.exec/server_alive_check.sh

The path can be overridden through `SERVER_ALIVE_CHECK`.

If the target does not exist or is not a regular file, the plugin returns `127`.

If it exists but is not executable, the plugin returns `126`.

If it is executable, the plugin runs it and propagates its exit status.

### 6.4 `15_get_hardware_info`

`15_get_hardware_info` records hardware and low-level system information.

Depending on which commands are available, it can report:

- DMI system information
- PCI devices
- Battery and power information
- NetworkManager configuration
- Resolver status
- `/etc/resolv.conf`
- SATA and SCSI SMART information
- NVMe SMART information
- Disk serial numbers

## 7. System Maintenance

### 7.1 `20_system_upgrade`

`20_system_upgrade` performs operating-system package maintenance.

On Debian and Ubuntu systems it runs:

    apt-get update
    apt-get -y upgrade
    apt-get autoclean
    apt-get -y autoremove

On Red Hat and CentOS systems it runs:

    yum -y update
    yum clean all

If `package-cleanup` is available, it can also remove old kernels according to `OLDKERNELS_COUNT`.

If `freshclam` is available, the plugin also performs a ClamAV definition update. When `systemctl` is available, it is used to stop and restart `clamav-freshclam.service` around the update; a stop or start failure contributes to this plugin's failure status alongside a `freshclam` failure.

### 7.2 `25_ubuntu_kernel_upgrade`

`25_ubuntu_kernel_upgrade` updates Ubuntu kernel packages.

It first purges old kernel packages while excluding the currently running kernel, then installs:

    linux-image-$UBUNTU_ARCHITECTURE
    linux-headers-$UBUNTU_ARCHITECTURE
    linux-$UBUNTU_ARCHITECTURE

This is a system-maintenance plugin that changes package state; it is not a reporting-only component.

## 8. Database and Repository Dumps

### 8.1 Dump Feature Summary

| Plugin | Target | Output | Main configuration |
| --- | --- | --- | --- |
| `30_dump_mysql` | MySQL databases | `<database>.sql.gz` | `MYSQL_DBS`, `MYSQL_USER`, `MYSQL_PASS`, `MYSQLDUMP` |
| `31_dump_postgresql` | PostgreSQL cluster | `all.dump.gz` | `PGDUMP`, `PG_USER` |
| `32_dump_mongodb` | MongoDB | Configured ZIP archive | `MONGODUMP_BIN`, `MONGODBDUMP_PATH`, `MONGODBDUMP` |
| `35_dump_svn` | SVN repositories | `<repository>.zip` | `SVN_REPOS`, `SVN_PATH`, `SVNDUMP` |

### 8.2 `30_dump_mysql`

`30_dump_mysql` processes every database listed in `MYSQL_DBS`.

Each database is dumped through `mysqldump` and compressed with gzip.

Failure of one database does not stop processing of the remaining configured databases.

The current implementation passes `MYSQL_PASS` to `mysqldump` on the command line.

This can expose the password in the local process list. Environments where that matters should use a MySQL option file such as `~/.my.cnf`.

### 8.3 `31_dump_postgresql`

`31_dump_postgresql` runs `pg_dumpall -c` and stores the result as:

    all.dump.gz

The database command runs under `PG_USER`.

The change of directory into `PGDUMP` is confined to a subshell, so it does not affect plugins sourced afterward.

### 8.4 `32_dump_mongodb`

`32_dump_mongodb` uses the configured `mongodump` binary to create a temporary dump tree and then packages that tree into the configured ZIP archive.

After the archive is created successfully, the contents of the temporary dump directory are removed.

If the temporary dump directory or the parent directory of the archive does not exist, the plugin skips the operation instead of creating the missing directories.

### 8.5 `35_dump_svn`

`35_dump_svn` processes every repository listed in `SVN_REPOS`.

It runs `svnadmin dump` for each repository and creates a ZIP archive for each result.

Failure of one repository does not stop processing of the remaining configured repositories.

## 9. Local Incremental Backup

`70_incremental_backup` is the main local backup plugin.

It synchronizes every directory listed in `BACKUPDIRS` into `BACKUPTO` through rsync.

The configured rsync behavior includes:

- Archive mode
- Verbose output
- Deletion of destination files removed from the source
- Deletion of excluded destination files
- Preservation of overwritten or deleted destination files in a backup directory
- Dry-run support

The version-preservation directory is:

    $BACKUPTO/_backup_$DATE

As a result, `BACKUPTO` can contain both the current mirror and dated copies of files replaced or deleted during synchronization.

## 10. Backup Retention

Backup directories matching exactly:

    _backup_YYYYMMDD

directly below `BACKUPTO` become purge candidates when they are older than `EXPIREDAYS`. A directory with any other prefix is not a purge candidate.

`EXPIREDAYS` must be a non-negative integer. An unset, empty, or non-numeric value causes the local backup plugin to skip both retention cleanup and the rsync backup, returning status `3`.

If the retention cutoff cannot be calculated, or if deleting an expired backup directory fails, the local backup plugin returns status `1` and does not proceed to the rsync backup for that run.

If no matching backup directories exist, nothing is removed.

## 11. Exclusions

If `EXCLUDEFILE` exists, blank lines and comment-only lines are stripped from its contents, and the rest is supplied to rsync via `--exclude-from=/dev/stdin`.

If `EXCLUDEFILE` is absent or not a regular file, the backup runs without an exclude option.

If `EXCLUDEFILE` exists but is not readable, the local backup plugin returns status `3` and skips the backup instead of running rsync without the intended exclusions.

This keeps backup exclusions in configuration data instead of hard-coding them into the backup implementation.

## 12. Dry-Run Behavior

The local and remote rsync-based plugins support:

    DRY_RUN=true

The plugins that currently honor this setting include:

- `70_incremental_backup`
- `80_backup_to_remote`
- `85_get_remote_dir`

Dry-run is intended to show what synchronization would do before write or deletion operations are performed.

It should not be treated as a universal no-op switch for every plugin in deferred-sync.

## 13. Remote Synchronization

deferred-sync supports synchronization in both directions.

| Direction | Plugin | Behavior |
| --- | --- | --- |
| Local → Remote | `80_backup_to_remote` | Sends the local backup tree to remote hosts |
| Remote → Local | `85_get_remote_dir` | Retrieves remote directories into local storage |

Neither plugin performs a pre-flight network reachability check (such as `ping`) before attempting a transfer. Whether a host or port is reachable depends on network security requirements (firewalls, security groups, filtering) outside these plugins' control, so a separate reachability probe would not reliably predict whether rsync/ssh can actually connect. Each plugin instead attempts the transfer directly and returns rsync's own exit status for that host, unnormalized.

### 13.1 `80_backup_to_remote`

`80_backup_to_remote` synchronizes `BACKUPTO` to:

    BACKUPUSER@REMOTE_HOST:REMOTE_DIR

Multiple hosts can be listed in `REMOTE_HOSTS`.

If one remote host's transfer fails, that host's rsync exit status is kept while processing continues for the remaining hosts.

The rsync invocation uses `--delete`, so files absent from the local source can be removed from the remote destination.

### 13.2 `85_get_remote_dir`

`85_get_remote_dir` processes combinations of `GET_HOSTS` and `GET_REMOTE_DIRS`.

Retrieved data is synchronized below:

    $GET_TARGET_DIR/<host>

This plugin also uses rsync `--delete`.

A failed transfer for one host keeps that host's rsync exit status, unnormalized.

A missing local target directory produces status `3`.

## 14. Configuration Reference

The main configuration groups are:

| Category | Main variables | Purpose |
| --- | --- | --- |
| General | `DRY_RUN`, `EXCLUDEFILE`, `JOBLOG`, `STARTSCRIPT`, `ENDSCRIPT`, `ADMIN_MAIL_ADDRESS` | Controls the overall job |
| Plugin selection | `LOAD_PLUGINS_ALL`, `PLUGINS` | Selects which plugins run |
| System upgrade | `OLDKERNELS_COUNT` | Controls old-kernel retention on the relevant Red Hat path |
| Ubuntu kernel | `UBUNTU_ARCHITECTURE` | Selects the Ubuntu kernel flavor to install |
| MySQL | `MYSQL_DBS`, `MYSQL_USER`, `MYSQL_PASS`, `MYSQLDUMP` | Configures MySQL dumps |
| PostgreSQL | `PGDUMP`, `PG_USER` | Configures PostgreSQL dumps |
| MongoDB | `MONGODUMP_BIN`, `MONGODBDUMP_PATH`, `MONGODBDUMP` | Configures MongoDB dumps |
| SVN | `SVN_REPOS`, `SVN_PATH`, `SVNDUMP` | Configures SVN dumps |
| Local backup | `BACKUPDIRS`, `BACKUPTO`, `EXPIREDAYS` | Configures local incremental backup |
| Remote backup | `REMOTE_HOSTS`, `REMOTE_DIR`, `BACKUPUSER` | Configures local-to-remote synchronization |
| Remote retrieval | `GET_HOSTS`, `GET_REMOTE_DIRS`, `GET_TARGET_DIR`, `REMOTE_USER` | Configures remote-to-local synchronization |

For exact configuration semantics, refer to `config/sync.conf` and the header documentation and implementation of the plugin that reads each value.

## 15. Missing Prerequisites

deferred-sync does not generally treat a missing backup or dump destination as something it should silently create.

A missing directory may indicate that:

- A filesystem failed to mount
- Backup storage is disconnected
- Configuration is incomplete

Many plugins therefore return status `3` and skip the operation when a required local directory is absent.

This prevents a failed mount from being masked by automatically creating an ordinary directory on the root filesystem and then reporting a misleadingly successful backup.

## 16. Warn and Continue

A major design property of deferred-sync is warn-and-continue behavior.

The plugin loader sources each selected plugin in sequence.

A nonzero return status from one plugin does not prevent later plugins from running.

When several plugins fail, the loader preserves the first nonzero status.

The same principle applies to the main phases: failure of `STARTSCRIPT`, the plugin loader, or `ENDSCRIPT` is logged, but does not automatically stop later phases.

This avoids failure chains such as:

    hardware reporting failed
        ↓
    database dump never ran
        ↓
    backup never ran

## 17. Return Status

The standard return-status convention is:

| Status | Meaning | Typical case |
| ---: | --- | --- |
| 0 | Success | The operation completed |
| 1 | Command failure or resource failure | An external command or required resource failed |
| 2 | Network unreachable | A remote host or network operation could not be reached |
| 3 | Local prerequisite missing | A required directory, configuration value, or local environment is absent |

Some wrapper plugins propagate external command statuses directly.

`11_server_alive_check` also uses the POSIX conventions:

- `126`: the target exists but is not executable
- `127`: the target script does not exist or is not a regular file

## 18. Logging

Runtime output is written to `JOBLOG`.

The repository configuration uses:

    /var/log/deferred-sync/sync.log

The main log prefixes are:

    [INFO]
    [WARN]
    [ERROR]

Because deferred-sync is designed for unattended execution, major phases and long-running operations record timestamps.

External commands also record their return status after execution.

## 19. Administrator Notification

If `ADMIN_MAIL_ADDRESS` is configured, deferred-sync sends `JOBLOG` by mail after the job finishes.

The subject contains:

    [cron]
    hostname

If `nkf` is available, it is used in the mail pipeline.

If `nkf` is unavailable, the log is passed directly to `mail`.

Mail delivery failure is reported as an error.

## 20. Installation Modes

`install.sh` supports several installation modes.

| Mode | Target | Cron / logrotate | sudo | Notes |
| --- | --- | --- | --- | --- |
| Default | `/opt/deferred-sync` | Configured | Used unless run as root | Standard system-wide installation |
| Custom target | Explicit absolute path | Skipped | Used unless run as root | Deploys components only |
| `--no-sudo` / `-n` / `nosudo` | Default or custom | Depends on installation mode | Not used | Suitable for user-controlled targets |
| `--link` | Default installation model | Adds optional integration links | Used unless run as root | Integrates with `/etc/cron.config` and `/etc/cron.exec` |
| `--uninstall` | Fixed at `/opt/deferred-sync` | Removes related installed components | Used unless run as root | Does not automatically remove custom targets |

Root installs and uninstalls perform privileged operations directly, without invoking `sudo`.

A standard system-wide installation deploys the core components and can also configure cron, logrotate, configuration directories, and backup directories.

Existing:

    /etc/opt/deferred-sync/sync.conf
    /etc/opt/deferred-sync/exclude.conf

are not overwritten during installation.

## 21. Optional System Integration Links

With `--link`, the installer can create:

    /etc/cron.config/sync.conf
        → /etc/opt/deferred-sync/sync.conf

    /etc/cron.config/exclude.conf
        → /etc/opt/deferred-sync/exclude.conf

    /etc/cron.exec/deferred-sync
        → /opt/deferred-sync/exec/deferred-sync

This integrates deferred-sync with a centralized cron execution and configuration layout.

## 22. Cron Execution

deferred-sync is designed primarily for unattended scheduled operation.

A default system-wide installation can use:

    /etc/cron.daily/deferred-sync

For an exact schedule, the repository also provides:

    cron/cron.d/deferred-sync

as a sample cron.d entry.

If `/etc/cron.d/deferred-sync` already exists, the installer skips installation of `/etc/cron.daily/deferred-sync` to avoid duplicate scheduling.

## 23. Destructive Operations

deferred-sync is a backup and synchronization system, not a read-only inspection tool.

Several features intentionally modify system state or stored data.

| Operation | Component | Main side effect |
| --- | --- | --- |
| Package update | `20_system_upgrade` | Updates or removes installed packages |
| Kernel maintenance | `20_system_upgrade`, `25_ubuntu_kernel_upgrade` | Removes old kernels and installs kernel packages |
| Dump replacement | `30_*`, `31_*`, `32_*`, `35_*` | Replaces previous dump artifacts |
| Local mirroring | `70_incremental_backup` | Uses rsync `--delete` and `--delete-excluded` to align the destination with the source |
| Old-backup purge | `70_incremental_backup` | Removes backup generations beyond the retention period |
| Remote mirroring | `80_backup_to_remote` | Uses rsync `--delete` on the remote destination |
| Remote retrieval | `85_get_remote_dir` | Uses rsync `--delete` on the local retrieval destination |
| Installation | `install.sh` | Changes the installation tree, cron, configuration, logrotate, and permissions |
| Uninstallation | `install.sh --uninstall` | Removes installed components from the default installation |

Configuration and target paths should therefore be reviewed before enabling state-changing plugins.

## 24. Root Execution and Privilege

Scheduled execution is designed to run as root.

That does not mean every operation is performed under the root identity.

For example, PostgreSQL dumping uses:

    sudo -u "$PG_USER"

to perform the database operation under the configured PostgreSQL user.

System-wide configuration files can contain credentials and are therefore deployed with restrictive permissions.

## 25. Finding a Feature by Purpose

| Goal | Plugin or component |
| --- | --- |
| Record installed software versions | `09_show_version` |
| Record CPU, memory, disk, and network state | `10_get_resources` |
| Integrate an existing server-alive check | `11_server_alive_check` |
| Record SMART, PCI, DNS, and related hardware information | `15_get_hardware_info` |
| Upgrade operating-system packages | `20_system_upgrade` |
| Upgrade Ubuntu kernels | `25_ubuntu_kernel_upgrade` |
| Dump MySQL databases | `30_dump_mysql` |
| Dump a PostgreSQL cluster | `31_dump_postgresql` |
| Dump MongoDB | `32_dump_mongodb` |
| Dump SVN repositories | `35_dump_svn` |
| Create versioned local filesystem backups | `70_incremental_backup` |
| Replicate local backups to another server | `80_backup_to_remote` |
| Collect backup data from another server | `85_get_remote_dir` |
| Change which tasks run | `config/sync.conf` |
| Add pre-run or post-run work | `STARTSCRIPT`, `ENDSCRIPT` |
| Change scheduling | `cron/` |
| Install or uninstall deferred-sync | `install.sh` |

## 26. Typical Configurations

### Minimal Local Backup

A configuration close to the repository default runs:

    get_resources
        ↓
    incremental_backup

This records the current system state before creating the local backup.

### Database Server

A database server can use an order such as:

    get_resources
        ↓
    dump_mysql
        ↓
    dump_postgresql
        ↓
    incremental_backup
        ↓
    backup_to_remote

Creating the dumps first allows them to be included in the same local and remote backup cycle.

### Backup Aggregation Server

A backup server can combine its own local backup with retrieval from other hosts:

    get_resources
        ↓
    incremental_backup
        ↓
    get_remote_dir

This allows local backup and remote backup collection to use the same execution framework.

## 27. Scope of This Document

This `FEATURES.md` answers:

"What does deferred-sync provide to its users?"

It covers:

- Core execution flow
- Plugin loading
- Reporting
- System maintenance
- Database and repository dumps
- Local incremental backup
- Backup retention
- Remote synchronization
- Configuration
- Failure handling
- Logging
- Administrator notification
- Installation
- Cron integration
- Destructive behavior

It does not duplicate in full:

- Every plugin header
- The complete implementation policy
- Version history
- General rsync, SSH, cron, or database-tool manuals
- Host-specific configuration values
- Credentials

The implementation and each component's header documentation remain authoritative for exact behavior.

`doc/POLICY.md` defines the implementation and operational contract.

The purpose of this `FEATURES.md` is to let a user determine, before reading the source tree in detail:

- Which capabilities exist
- Which plugin should be enabled
- Which operations can modify or delete data
- Which configuration controls each capability
