# deferred-sync Implementation Policy

This document defines the implementation and maintenance policy of this
repository. It covers the scheduled run, sourced components and plugins,
configuration, installer, documentation, versioning, and validation.

Three kinds of operational file live here, and their rules follow from how
they are used.

- The run: `exec/deferred-sync`, `lib/load`, `lib/before`, `lib/after`, and
  `lib/plugins/*`. These files form the unattended backup and synchronization
  job. The main executable may also be run manually.
- The configuration: `config/sync.conf` and `config/exclude.conf`. The copies
  in this repository are templates for a new installation. A deployed
  configuration is persistent host-specific runtime state.
- The installer: `install.sh`. It is an executable POSIX shell program run
  interactively to install, update, link, or uninstall deferred-sync.

## 1. About This Document

### 1.1 Decision Priorities

When requirements compete, make the design decision in this order:

1. **Compatibility**
2. **Safety**
3. **Efficiency**

This is a priority order, not an equally weighted checklist.

**Compatibility** means preserving normal and intended observable behavior
and keeping the supported execution environments working. In this repository
that includes the warn-and-continue execution model, the sourced-plugin
contract, plugin execution semantics and ordering, configuration keys and
their meanings, configured plugin names, return-status semantics, and the
documented POSIX shell compatibility target.

Compatibility does not mean preserving whatever the current implementation
happens to do. A clear bug, regression, unintended side effect, or broken
behavior is not preserved merely because it already exists.

**Safety** comes after Compatibility and before Efficiency. In this repository
it includes keeping destructive operations inside their intended targets,
treating a missing mount or destination as a missing prerequisite rather than
silently creating it, limiting privileged operations, protecting credentials,
and avoiding unsafe continuation.

**Efficiency** means avoiding unnecessary processing, process creation, I/O,
network access, and resource consumption. Efficiency does not justify
weakening Compatibility or Safety.

Changes to supported environments, support floors, repository release
versions, deliberate retirement of an established interface, and
repository-wide design policy are maintainer decisions.

### 1.2 Documentation Roles and Sources of Truth

The documentation structure of this repository is:

- `doc/POLICY.md` records the repository-wide implementation and maintenance
  policy.
- `doc/FEATURES.md` is the detailed user-facing behavior and capability
  reference.
- `README.md` provides the project overview, installation instructions, basic
  configuration, supported environments, usage, and directory structure.
- `doc/VERSIONS` records release-level history.
- A component header records the local interface and operational contract
  needed to understand or operate that component.
- `config/sync.conf` is the configuration template used for a new
  installation. A deployed configuration is persistent host-specific runtime
  state.

The implementation is the primary evidence of what currently happens. It is
not, by itself, proof that the current behavior is the intended specification.

When implementation and documentation disagree, compare the implementation,
documented interface, component header, history, existing design, and
maintenance intent. If the implementation contains a regression, do not adopt
that regression as the specification merely because it is present in the
current code.

### 1.3 Wording Strength

Reserve absolute wording such as `must`, `always`, and `never` for an
invariant that admits no reasonable exception.

Use wording such as `prefer`, `should`, or `when appropriate` for a design
preference or situational rule.

A rule must not be written so that applying its wording literally produces a
result contrary to Compatibility, Safety, or Efficiency. Where wording and
purpose conflict, the priorities and intended behavior defined above govern.

This is not a formal MUST/SHOULD/MAY taxonomy.

### 1.4 Change Discipline for Established Infrastructure

Finding a possible safety, compatibility, maintainability, cleanup, or
refactoring improvement does not by itself authorize an implementation
change.

Documentation work, policy work, review, diagnostics, cleanup, or another
task whose stated scope does not include an implementation change must not
expand into one merely because an improvement opportunity is discovered.

A safety-motivated change is not automatically justified by Safety having
priority over Efficiency. Added complexity can itself create new failure
modes, compatibility risk, operational risk, and maintenance cost. This is
especially important in infrastructure software whose established behavior is
part of the system it supports.

Before changing established behavior, weigh the probability and impact of the
failure being prevented against the added complexity, new failure modes,
compatibility risk, operational cost, maintenance cost, and rollback cost.

Behavior that has operated reliably over time is evidence and has value of
its own. Do not refactor backup, synchronization, scheduling, installation,
or other infrastructure behavior merely because another design appears
cleaner, more modern, or more defensive.

An implementation change is made only when that change has been explicitly
chosen as part of the work being performed. Before deployment, validate it in
the supported and representative operating systems, shells, utilities, and
deployment conditions affected by the change. A successful check in one
convenient environment is not sufficient evidence for a change whose
compatibility or operational risk extends to other supported environments.

## 2. What a Run Is

deferred-sync is primarily designed for unattended scheduled backup,
synchronization, inspection, dump, and maintenance work. A system-wide run
normally has the privileges required for those operations. The main executable
may also be invoked manually.

The exact schedule is deployment configuration, not an implementation-policy
invariant. The repository supplies both a `cron.daily` wrapper and a
`cron.d` sample with an explicit schedule.

The run performs operations that can change or remove data, including
`rsync --delete`, retention cleanup, database and repository dumps, remote
synchronization, and optional system maintenance.

Three operational requirements follow.

- **Do not destroy what the operation was not asked to touch.** Destructive
  targets and prerequisites are checked before modification.
- **Continue independent work after a task failure.** Once setup has
  succeeded, failure of one independent phase, plugin, database, repository,
  or remote host does not by itself cancel the remaining independent work.
- **Leave enough information to diagnose the run later.** The job is normally
  unattended, so its log must identify phases, failures, return statuses, and
  useful timing information.

The continue-after-failure rule does not require unsafe continuation.
Execution may stop when required configuration cannot be read, the job log
cannot be used safely, a prerequisite required for further execution is
missing, or continuing would itself be destructive or unsafe.

## 3. The Contract Between the Core and a Plugin

### 3.1 Sourced, Not Executed

A plugin is sourced into the shell that runs the whole job. It is not a child
process, and it does not get its own anything. `lib/plugins/*` and `lib/*` are
therefore not executable, and carry `#!/bin/sh` to name the language they are
written in rather than to be run.

- **Never terminate the parent job with `exit` from a sourced component.**
  Normal completion of a sourced plugin or hook returns to its caller.
  An `exit` used inside a subshell only to terminate that subshell is
  allowed because it does not terminate the parent job.
- **Confine a change of the working directory to a subshell.** A bare `cd`
  leaks into every plugin sourced afterwards, which is why
  `31_dump_postgresql` wraps its dump in `( ... )`.
- **Own your variable names.** POSIX `sh` has no `local`, so every name a
  plugin sets is visible to the next one. A name that reads like a general
  word is a collision waiting to happen: `20_system_upgrade` uses `YUM_FAILED`
  precisely because `FAILED` belonged to its caller. Name a working variable
  after the plugin that owns it, or unset it before returning.
- **Depend only on the core.** `SCRIPT_HOME`, `JOBLOG`, `DATE`, and the keys
  of `sync.conf` are the interface. A variable another plugin happened to set
  is not, and a plugin must not be made to work by placing it after another
  one in the order.
- **Use a default only when it is safe and behavior-preserving.** A new
  configuration value uses a default when that default preserves the
  established behavior of a deployed configuration that does not contain
  the new key. When no safe default exists, the component does not invent
  one: it reports the missing prerequisite and returns status `3`.
- The same rules bind `lib/before` and `lib/after`. They are sourced too.

### 3.2 Warn and Continue

- `exec/deferred-sync` runs `STARTSCRIPT`, then the plugin loader, then
  `ENDSCRIPT`. A non-zero status from any of them is reported as `[WARN]` and
  the next phase starts regardless.
- `lib/load` sources each enabled plugin in turn, reports a non-zero status as
  `[WARN]`, keeps the **first** non-zero status in `FAILED_STATUS`, and
  returns it once every plugin has run.
- A normal task failure does not abort the remaining independent work.
  A component that detects a condition making its own operation unsafe
  declines that operation and returns a non-zero status. A prerequisite
  failure that prevents the run itself from being established may stop
  execution as described in Section 2.
- The first status is kept rather than the last because the first failure is
  usually the cause and the rest are its consequences.

### 3.3 Return Codes

| Code | Meaning | Typical case |
|:----:|:---|:---|
| **0** | Success | The operation completed |
| **1** | Command failure or resource missing | A command failed, a database is absent, a permission is refused |
| **2** | Network unreachable | A host does not answer, `ping` fails, SSH cannot connect |
| **3** | Local prerequisite missing | A directory or configuration is absent, the environment is not initialized |

- Codes `0` through `3` are the standard semantic status vocabulary used
  by the core and plugins.
- A wrapper around an external command may intentionally propagate that
  command's status instead. When it does, the component header documents
  that behavior and the loader still treats every non-zero result as a
  warning and continues with independent work.
- `11_server_alive_check` uses the conventional `127` status when its
  configured target does not exist or is not a regular file and `126`
  when it exists but is not executable, and otherwise propagates the
  status of the target it runs.
- The system-maintenance plugins may propagate the status of package
  commands they execute.
- A plugin that performs the same operation over a configured list
  continues through the list and returns a non-zero aggregate result
  rather than stopping at the first failed item.

### 3.4 Order

- A plugin file is named `NN_name`, and the numeric prefix is the order in
  which `lib/load` sources it. The order encodes operational and data-flow
  sequencing, not an inter-plugin API dependency:
  information is gathered before the system is changed, dumps are written
  before the backup that copies them, and the local backup completes before it
  is pushed to a remote host. `BACKUPDIRS` in `config/sync.conf` lists
  `/home/mysqldump` and `/home/svndump`, so `30_dump_mysql` and `35_dump_svn`
  running after `70_incremental_backup` would back up yesterday's dump.
- A new plugin takes the number required by its operational and data-flow
  sequencing relative to the existing plugins. The existing bands
  are 09-15 for reporting, 20-25 for system upgrades, 30-35 for dumps, 70 for
  the local backup, and 80-85 for remote transfers. Leave gaps.
- `PLUGINS` entries are matched against the end of the file name, so
  `get_resources` selects `10_get_resources`. A plugin name is part of the
  deployed configuration interface. Renaming a plugin can break a host whose
  `PLUGINS` setting refers to that name, so a plugin is not renamed merely as
  a routine refactoring, and section 5.1 applies to the name as much as to a
  key.

## 4. Safety

### 4.1 A Missing Prerequisite Is Not Something to Create

- A plugin checks that its target directory exists, and returns `3` when it
  does not. It does not create it, and it does not create a parent for it.
- This is the rule that keeps a failed mount from turning into a silent
  success. A backup written to a directory the plugin created itself lands on
  the root filesystem, reports `0`, and is discovered to be worthless on the
  day it is needed. The absent directory is the signal that the disk is not
  there; erasing that signal is worse than skipping the run.
- The same holds for a configuration value that is empty. `31_dump_postgresql`
  returns `3` on an empty `PGDUMP` before it touches anything.
- A skip is reported once, as `[WARN]`, naming what was missing. It is not
  reported as an error: an unattended job that cries at every run trains its
  reader to stop looking.

### 4.2 Destructive Operations

- Every `rm` and every `--delete` is bounded by a pattern that cannot widen to
  the whole filesystem. `purge_expires` iterates `"$BACKUPTO"/*_backup_*` and
  compares a date parsed out of the name before removing anything.
- Compute the target of a removal, then check it, then remove it. Do not let a
  glob that matched nothing, or an unset variable, reach `rm`.
- `DRY_RUN=true` controls the dry-run behavior of the rsync-based
  synchronization paths that explicitly add rsync's `--dry-run` option.
  It is not a repository-wide no-op switch and must not be described as a
  safety sandbox for every plugin or destructive operation. In
  particular, retention cleanup is not suppressed merely because
  `DRY_RUN=true`.
- A fixed path is safer than a configured one where the operation cannot be
  undone: `install.sh --uninstall` removes `/opt/deferred-sync` and refuses to
  follow a custom target, and `safe_symlink` aborts rather than replace a
  directory.
- Do not claim atomic replacement or preservation of the previous
  successful artifact unless the implementation actually provides that
  guarantee. The current dump plugins do not provide a repository-wide
  last-known-good replacement guarantee, so this policy does not state
  one.

### 4.3 Repeated and Concurrent Runs

- Sequential repeatability is required: after one run has completed, running
  the same configured job again must not widen a destructive target or create
  accidental cumulative state merely because it is a rerun.
- Concurrent or overlapping runs are not a supported operating mode. This
  repository does not provide a lock, pidfile, `flock`, or another
  concurrency-control mechanism.
- Deployment and operations must prevent a second run from starting while a
  previous run is still active. This is an operational requirement, not an
  implementation guarantee of overlap safety.
- Do not test or document arbitrary overlapping execution as a supported
  capability unless concurrency control is deliberately introduced by a
  separately authorized implementation change.

### 4.4 Privilege

- The job runs as root, and that is not a licence to use it. A step that
  needs another identity asks for exactly that step, as `31_dump_postgresql`
  does with `sudo -u "$PG_USER"`.
- Deployed configuration is `0640` and owned by root, because it holds
  credentials. A plugin does not loosen a mode it did not set.

## 5. Configuration

The repository copies of `config/sync.conf` and `config/exclude.conf` are
templates for a new installation. A deployed system configuration is
persistent host-specific runtime state.

A standard system installation preserves an existing deployed
configuration instead of replacing it on upgrade. New code must therefore
remain compatible with established configuration keys and value semantics.

### 5.1 A Key Is a Promise

`install.sh` never overwrites an existing `/etc/opt/deferred-sync/sync.conf`.
An upgraded host therefore keeps the file it has had for years, and the new
code must read it.

- Do not rename a key, do not repurpose one, and do not change what a value
  means. The host that would break is not visible from here.
- A new key is read as `${KEY:-default}`, with a default that keeps the
  existing behaviour for a host that has never heard of it.
  `SERVER_ALIVE_CHECK` and `OLDKERNELS_COUNT` are the pattern.
- A key whose absence cannot be given a safe default makes the plugin return
  `3` and say which key is missing.
- `config/sync.conf` in the repository is the template a new host starts from.
  Adding a key there does not deliver it to an existing host, so the code, not
  the template, is where the default lives.

### 5.2 `sync.conf` Is Code

It is sourced by a root shell. Whatever it contains, runs.

- Keep it to assignments and comments. A command substitution is used only
  where the value genuinely has to be resolved on the host, as
  `REMOTE_DIR=/home/remote/$(hostname)` does, and it stays cheap and
  incapable of failing destructively.
- `$HOSTNAME` is not set under POSIX `sh`; `$(hostname)` is why that line
  reads as it does.
- The section layout of the file follows the plugins, each under the plugin
  number and name that reads it, so that a key can be found from a log line.

### 5.3 Host-Specific Logic Does Not Live in `lib/`

- `install.sh` removes the target directory and redeploys `exec`, `config`,
  and `lib` on every install. Only `/etc/opt/deferred-sync` survives an
  upgrade. Anything edited under `lib/` is lost the next time the installer
  runs.
- `lib/before` and `lib/after` are therefore examples of the shape a hook
  takes, not a place to keep one. A host that needs its own pre- or post-run
  logic keeps that script outside the installation target and points
  `STARTSCRIPT` or `ENDSCRIPT` at it. That is why they are configuration keys
  and not fixed paths.
- The same reasoning applies to a plugin edited in place on a host. A local
  change belongs in this repository or in a file the installer does not touch.

### 5.4 Secrets

- The repository holds placeholders and nothing else: `your_username`,
  `your_password`, `remote_server_name_or_IP`, `your_email@example.com`. No
  real host name, account, address, or key is committed, whether it still
  works or not.
- The log is mailed off the host. Nothing that reaches `JOBLOG` may contain a
  credential, and a command that would echo one is redirected or replaced.
- Where a credential cannot be kept off the command line, the header says so
  and names the alternative, as `30_dump_mysql` does about `mysqldump` and
  `~/.my.cnf`. A known weakness that is written down can be judged; one that
  is not is a surprise.

## 6. Logging

- Project-generated diagnostic and status messages use `[INFO]`, `[WARN]`,
  and `[ERROR]`: `[INFO]` records normal progress, `[WARN]` records a
  skipped or failed operation that does not by itself stop independent
  later work, and `[ERROR]` records a condition that prevents the current
  phase or required setup from completing.
- Job start and end boundary records may retain their existing `*** ...`
  form, and output emitted directly by an external command is not required
  to be rewritten with one of the three project prefixes.
- `[WARN]` and `[ERROR]` go to stderr, which `exec/deferred-sync` redirects
  into `JOBLOG` along with everything else. During a normal run nothing
  escapes to the terminal.
- A plugin announces itself when sourced and stamps that line with the time,
  and stamps the start of each long operation the same way:

```sh
start_message() {
    printf -- "[INFO] Loading: dump_mysql has been loaded at "
    date "+%Y/%m/%d %T"
}
```

- After an external command, report the status: `echo "[INFO] Return code is
  $RC"`. Reading a log that says only that a command ran tells you nothing.
- Phase boundaries and long-running operations carry timestamps because
  deferred-sync normally runs unattended and the log is inspected later.
  The timestamp helps identify which operation was active when a host
  slowed down, filled storage, or was interrupted.
- Do not store a timestamp and reuse it. Call `date` where the line is
  printed.
- Name the plugin in its own messages, not the file's number. The number is an
  ordering device and may change; the name is what the operator configured.

## 7. File Headers

### 7.1 The Run

Every file that the job sources opens with a shebang, a bare `#`, and a title
line naming the file and what it does in one sentence:

```sh
#!/bin/sh
#
# 30_dump_mysql - A script to dump MySQL databases and compress the dump.
#
```

Below that come only the sections the file needs, each a `#` line ending in a
colon, with its content indented by three spaces:

- `Description:` where the title line is not enough.
- `Required environment variables:` names every required configuration or
  environment value the component reads, spelled exactly as
  `sync.conf` spells it where applicable, with a one-line meaning and an
  `Example:`. The header is the component's exact local contract for those
  inputs. If the code reads a required value and the header omits it, the
  component header is incomplete.
- `Outputs:` for a plugin whose product is what it prints.
- `Behavior:` where the order or the failure handling is the point, as in
  `lib/load`.
- `Supported systems:` where the file only applies to some.
- `Note:` for what the reader must know before running it: an assumption about
  authentication, a dependency, a known weakness.

No author, no licence line, and no version history. Those belong to the
repository, and repeating them in every plugin creates unnecessary copies to
keep consistent.

### 7.2 `install.sh`

`install.sh` is an executable POSIX shell program and carries a structured
user-facing header delimited by separator lines. Its header contains the
description, identifying information, usage, options, notes, and its own
version history. `usage()` prints that header.

The installer provides `-h` / `--help` and `-v` / `--version`, checks the
external commands required by its execution path, checks sudo only when
privileged operation is required, and uses the repository's
`[INFO]` / `[WARN]` / `[ERROR]` diagnostic convention.

Its own version history uses `major.minor` independently of the repository
release version. A user-visible CLI, installation-behavior, safety, or
significant structural change may form a new installer release.
Documentation-only, comment-only, and formatting-only changes do not
require an installer version increment.

Each entry's description is at most two lines, and a single line at or
under 80 columns is preferred whenever practical.

The first entry, at the lowest version `install.sh`'s own history reaches,
reads only `Initial release.` and nothing else.

### 7.3 Configuration Files

A configuration file opens with its own path, a sentence saying what it
configures, and a `# Syntax:` block stating how values are written. Sections
are separated by a `# ----------------------` rule and named after the plugin
that reads them.

## 8. Comments

- A comment states why. The code already states what, and a comment that
  restates it is a second implementation of the same fact, in a language no
  interpreter checks.
- This repository has the evidence. Release v26.07 carries five separate
  corrections of comments and headers that had drifted from the code they
  described: the exclude filter, the mail fallback, the credential note, the
  SVN dump description, and the cron schedule. Every one of them had been
  accurate when written.
- So: write the reason, not the behaviour. `# Use a dedicated name so the
  caller's FAILED is not overwritten` earns its line, because without it the
  next reader simplifies the name back and breaks the caller.
- Where a comment must describe behaviour — a header's `Required environment
  variables:` and `Note:` — it is checked against the code whenever that code
  changes. That check is part of the change, not a later tidy-up.
- English, imperative, and as short as the reason allows. No banner, no
  divider inside a function, no `Function to ...` preamble, and no comment
  that repeats the line below it.

## 9. POSIX Shell

- Project-owned shell syntax, parameter expansion, function syntax, and
  shell-language behavior target POSIX `/bin/sh`. The README supports Solaris
  10 and RHEL 5, and `/bin/sh` is dash on Debian and Ubuntu. A construct that
  works because `/bin/sh` happens to be bash is a defect.
- No `local`, no arrays, no `[[ ... ]]`, no `function` keyword, no `source`, no
  process substitution, and no `echo -n`. Use `[ ... ]`, positional parameters
  or a space-separated string, `name()`, `.`, a temporary file or a pipeline,
  and `printf`.
- `set -e` is not used. The job's error handling is explicit status checking,
  and an implicit abort is exactly what section 3.2 forbids.
- Quote every expansion that is not deliberately being split. `$PLUGINS`,
  `$BACKUPDIRS`, `$MYSQL_DBS`, `$SVN_REPOS`, and `$OPTS` are unquoted on
  purpose, because word splitting is how a list configured as one string is
  read. Everything else is quoted.
- Branch on what the environment provides, not on what it is called: a file
  such as `/etc/debian_version`, or `command -v` for a program. Keep that
  detection in one place per question.
- POSIX shell compatibility does not mean that every external utility and
  every utility option used by every plugin must itself be specified by
  POSIX. An external command may be used when the required functionality
  depends on it. Optional commands are detected where they are used, and
  platform-specific functionality may have a narrower supported scope.
- The minimum operating-system versions listed in the README are
  compatibility and maintenance targets. The project is maintained for
  later releases as they appear; the `and later` wording does not claim
  that an unknown future release has already been tested. Changing a
  support floor is a maintainer decision. Individual plugins may support
  a narrower set of systems when their required capability is
  platform-specific.

## 10. Installer and Change Policy

### 10.1 Installer

`install.sh` is an executable POSIX `/bin/sh` installer.

- Its structured header and `usage()` describe the same user-facing
  interface.
- `-h` / `--help` show help.
- `-v` / `--version` show the header information.
- Required external commands are checked before the path that needs them
  proceeds.
- Sudo is checked only when the selected operation requires privileged
  execution.
- The established exit-status convention uses `0` for success, `1` for a
  general failure, `126` when a required command exists but is not
  executable, and `127` when a required command is unavailable.
- Uninstallation keeps its target fixed at `/opt/deferred-sync`; a custom
  installation target is not removed automatically.
- Existing persistent configuration under `/etc/opt/deferred-sync` is not
  overwritten during installation.
- The installer keeps its own `major.minor` version history independently
  of the repository release version.
- Each entry's description is at most two lines, and a single line at or
  under 80 columns is preferred whenever practical.
- The first entry, at the lowest version the installer's own history
  reaches, reads only `Initial release.` and nothing else.
- A documentation-only, comment-only, or formatting-only change does not
  increment the installer version.
- A helper owns the external-command prerequisites it directly uses. The
  standard header-extracting `usage()` calls `check_commands awk` immediately
  before invoking `awk`; a usage-only `awk` dependency is not carried in the
  install or uninstall command lists.
- Moving a usage-only `awk` prerequisite into `usage()` is prerequisite
  ownership normalization. By maintainer decision, that normalization alone
  does not increment the installer version or add a `Version History` entry.
- `check_sudo()` owns the `sudo` command prerequisite it directly uses and
  calls `check_commands sudo` immediately before invoking `sudo -v`.
- Adding `check_commands sudo` at the start of `check_sudo()` is prerequisite
  ownership normalization. By maintainer decision, that normalization alone
  does not increment the installer version or add a `Version History` entry.

### 10.2 Pull Requests and History

- A pull request has one coherent purpose.
- One coherent change is normally represented by one commit.
- Independent changes may be separate commits.
- Review corrections may amend and rewrite the branch so that the final
  diff represents the intended change without abandoned intermediate
  wording or code.
- Conflict resolution does not add unrelated history to the branch.
- `doc/VERSIONS` records release-level changes, not a chronological list
  of every commit or review correction.

## 11. Versions and Documents

- The repository version is `<year>.<month>`, recorded in
  [`VERSIONS`](VERSIONS) and used for the Git tag. The Version History
  Guidelines at the foot of that file govern the entries, including the
  two-line, 80-column bullet limit stated there and the first-version rule.
- Files of the run carry no version of their own. `doc/VERSIONS` is their
  history.
- `install.sh` keeps its own `major.minor` version history under the
  installer rules stated in this policy.
- The current Markdown documents are `README.md`, `doc/POLICY.md`,
  `doc/FEATURES.md`, and `doc/LICENSE.md`.
- `doc/COPYING`, `doc/COPYING.LESSER`, and `doc/VERSIONS` keep their
  current extensionless names. Existing public document paths are not
  renamed merely for formatting consistency.
- `.gitattributes` gives `diff=markdown` to `*.md`, so that a diff hunk header
  names the section it falls in. It is a diff aid and nothing more. No file is
  given `linguist-language`, and `doc/VERSIONS`, `doc/COPYING`, and
  `doc/COPYING.LESSER` are excluded.
- Plain text is wrapped near 80 columns where that is practical. A URL, a
  command, a table, or a line that is clearer whole may exceed it.

## 12. Judging a Change

Validation is selected according to the files and behavior changed.

- A shell implementation change includes an applicable POSIX shell syntax
  check.
- A behavior change is checked against the behavior it changes.
- A destructive-path runtime check uses isolated temporary data,
  temporary destinations, and test configuration. Production backup or
  synchronization targets are not validation targets.
- `DRY_RUN=true` is used only for an operation whose implementation
  actually honors it. It is not treated as a whole-program sandbox.
- A documentation-only change does not require an unrelated runtime
  execution merely to satisfy a checklist.
- No new test framework is required merely because a change is made.

Before it is proposed, a change answers these:

- Does it widen what the run can delete, overwrite, or send?
- Does it create something whose absence was the signal that a disk, a mount,
  or a service is missing?
- Does it still return rather than exit, and does the job survive its failure?
- Does it leave a variable or a working directory behind for the next plugin?
- Does it rename a configuration key, a plugin file, or a value's meaning that
  an installed host still uses?
- Does it put a credential, a real host name, or an account into the
  repository or into the log that is mailed?
- Is it safe when the same configured job runs again after the previous run
  has completed?
- Does the change preserve the operational assumption that a second run is
  not started while a previous run is still active, rather than silently
  introducing a dependency on overlapping execution?
- Does every key it reads appear in the file's header, spelled as `sync.conf`
  spells it?
- Which documents change with it: the file header, `doc/VERSIONS`, the
  README, `config/sync.conf`?

## 13. License

This repository is dual licensed under the GPL version 3 or the LGPL version
3, at the user's option. See [LICENSE](LICENSE.md), [COPYING](COPYING), and
[COPYING.LESSER](COPYING.LESSER).

Files of the run carry no licence header; the repository-wide terms cover
them. `install.sh` repeats the licence line in its header, so that a script
read on its own still states its terms.
