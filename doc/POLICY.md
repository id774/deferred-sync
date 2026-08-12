# deferred-sync Implementation Policy

This document states what the code in this repository is held to. It is the
whole implementation policy: the rules the README used to carry are stated
here, and the README points at this file rather than repeating it.

Three kinds of file live here, and what each is held to follows from when it
runs and with what privilege.

- The run: `exec/deferred-sync`, `lib/load`, `lib/before`, `lib/after`, and
  `lib/plugins/*`. Sourced by a shell that cron starts as root, unattended, on
  a schedule.
- The configuration: `config/sync.conf` and `config/exclude.conf`. Deployed to
  a host once and edited there, not here.
- The installer: `install.sh`. Run by hand, by a person who is watching, and
  bound by the policy of the companion repository
  [`scripts`](https://github.com/id774/scripts).

## 1. About This Document

- The rules apply to what is written from now on. Nothing here is a reason to
  rewrite a plugin that works. A file is brought into line when it is edited
  for another reason, and no further.
- Where this document and the code disagree, the code is what runs and this
  document is what was meant. Close the gap in the direction that section 2
  points.
- `scripts/doc/POLICY` governs a maintained toolset, not this repository.
  Section 10 states which of its rules hold here, which do not, and the one
  place where this repository deliberately does the opposite.

## 2. What a Run Is

Every rule below comes from this paragraph, and a question this document does
not answer is answered by reading it again.

`cron/cron.d/deferred-sync` runs `exec/deferred-sync` as root, Monday through
Saturday, at 03:01. Nobody is watching. What it does is destructive by nature:
`rsync --delete --delete-excluded` over a live tree, `rm -rf` over expired
backup directories, `mysqldump` and `svnadmin dump` over production data, and
`rsync` to hosts reached over SSH. What it leaves behind is a log file and, if
`ADMIN_MAIL_ADDRESS` is set, a mail carrying that log.

Three things follow, and they are the whole design.

- **Do not destroy what the run was not asked to touch.** The window in which
  a mistake here is noticed is a day wide, and the data it eats is the copy
  that existed to be restored from.
- **Do not stop.** A failure in one task must not cost the night's backup. A
  partial run that reports what it skipped is worth more than a clean abort.
- **Leave a log that answers the question later.** The log is the only witness.
  A message that cannot be read at breakfast, without the host in front of you,
  has not been written.

## 3. The Contract Between the Core and a Plugin

### 3.1 Sourced, Not Executed

A plugin is sourced into the shell that runs the whole job. It is not a child
process, and it does not get its own anything. `lib/plugins/*` and `lib/*` are
therefore not executable, and carry `#!/bin/sh` to name the language they are
written in rather than to be run.

- **Never `exit`.** `exit` in a sourced file ends the job, taking every
  later plugin with it. End with `return`, always.
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
- **Default what you need.** A plugin that reads a core variable supplies a
  fallback, as `70_incremental_backup` does with `DATE=${DATE:-$(date
  +%Y%m%d)}`, so that it still runs when it is the only plugin enabled.
- The same rules bind `lib/before` and `lib/after`. They are sourced too.

### 3.2 Warn and Continue

- `exec/deferred-sync` runs `STARTSCRIPT`, then the plugin loader, then
  `ENDSCRIPT`. A non-zero status from any of them is reported as `[WARN]` and
  the next phase starts regardless.
- `lib/load` sources each enabled plugin in turn, reports a non-zero status as
  `[WARN]`, keeps the **first** non-zero status in `FAILED_STATUS`, and
  returns it once every plugin has run.
- Neither of them aborts the job, and no change may make them. A condition
  severe enough that continuing would do damage is handled by the plugin that
  detects it, by declining to act and returning.
- The first status is kept rather than the last because the first failure is
  usually the cause and the rest are its consequences.

### 3.3 Return Codes

| Code | Meaning | Typical case |
|:----:|:---|:---|
| **0** | Success | The operation completed |
| **1** | Command failure or resource missing | A command failed, a database is absent, a permission is refused |
| **2** | Network unreachable | A host does not answer, `ping` fails, SSH cannot connect |
| **3** | Local prerequisite missing | A directory or configuration is absent, the environment is not initialized |

- Every plugin and every core component returns one of these, and the loader
  applies warn-and-continue to all of them alike.
- A plugin that is a wrapper around one external command may propagate that
  command's status instead, and then the header says so. Two do:
  `11_server_alive_check` returns `127` when the target script does not exist
  and `126` when it exists but is not executable, following the POSIX shell
  convention, and otherwise the status of the script it ran;
  `20_system_upgrade` and `25_ubuntu_kernel_upgrade` return the status of
  `apt-get`, `yum`, or `package-cleanup`.
- A plugin that performs the same operation over a list keeps going through
  the list and returns a non-zero status from it, rather than returning at the
  first failure. `dump_svn`, `dump_mysql`, `backup_to_remote`, and
  `get_remote_dir` all take this form.

### 3.4 Order

- A plugin file is named `NN_name`, and the numeric prefix is the order in
  which `lib/load` sources it. The order encodes dependency, not preference:
  information is gathered before the system is changed, dumps are written
  before the backup that copies them, and the local backup completes before it
  is pushed to a remote host. `BACKUPDIRS` in `config/sync.conf` lists
  `/home/mysqldump` and `/home/svndump`, so `30_dump_mysql` and `35_dump_svn`
  running after `70_incremental_backup` would back up yesterday's dump.
- A new plugin takes the number its dependencies give it. The existing bands
  are 09-15 for reporting, 20-25 for system upgrades, 30-35 for dumps, 70 for
  the local backup, and 80-85 for remote transfers. Leave gaps.
- `PLUGINS` entries are matched against the end of the file name, so
  `get_resources` selects `10_get_resources`. Renaming a plugin therefore
  breaks the `sync.conf` of every installed host, and section 5.1 applies to
  the name as much as to a key.

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
- `DRY_RUN` reaches every command that writes or deletes on a remote or a
  backup tree. A new operation of that kind honours it too, and prints what it
  would have done.
- A fixed path is safer than a configured one where the operation cannot be
  undone: `install.sh --uninstall` removes `/opt/deferred-sync` and refuses to
  follow a custom target, and `safe_symlink` aborts rather than replace a
  directory.
- Where an operation replaces a previous artefact, it removes the old one only
  after the new one is written, or it removes a name it is about to rewrite in
  the same step. It does not delete first and hope.

### 4.3 Running Twice

- A run must be safe to repeat, and safe to overlap with the tail of a
  previous one. Cron does not check whether yesterday's job finished.
- An operation that is not naturally repeatable is made so by the name it
  writes to. A dump named after the database, overwritten each night, is
  repeatable; one that appends is not.

### 4.4 Privilege

- The job runs as root, and that is not a licence to use it. A step that
  needs another identity asks for exactly that step, as `31_dump_postgresql`
  does with `sudo -u "$PG_USER"`.
- Deployed configuration is `0640` and owned by root, because it holds
  credentials. A plugin does not loosen a mode it did not set.

## 5. Configuration

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

- Three prefixes, and no others: `[INFO]` for what happened, `[WARN]` for what
  was skipped or failed without stopping the run, `[ERROR]` for a condition
  that ends the phase.
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
- This timestamping is a deliberate departure from `scripts/doc/POLICY`
  section 2.4, which asks that ordinary log messages carry no timestamp. That
  rule is written for a tool a person watches. Here the log is read hours
  later, and the first question is which phase was running when the host
  became slow, filled its disk, or was rebooted. The time on every phase
  boundary answers it; a bare sequence of messages does not.
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
- `Required environment variables:` naming every key the file reads, spelled
  exactly as `sync.conf` spells it, each with a one-line meaning and an
  `Example:`. **This is the only documentation those keys have.** A key the
  code reads and the header omits is undocumented everywhere.
- `Outputs:` for a plugin whose product is what it prints.
- `Behavior:` where the order or the failure handling is the point, as in
  `lib/load`.
- `Supported systems:` where the file only applies to some.
- `Note:` for what the reader must know before running it: an assumption about
  authentication, a dependency, a known weakness.

No author, no licence line, and no version history. Those belong to the
repository, and repeating them in thirteen plugins creates thirteen copies to
keep true.

### 7.2 `install.sh`

`install.sh` carries the structured header of `scripts/doc/POLICY` section
1.6.1 instead: the `#` block with `Description`, the identifying block,
`Usage`, `Options`, `Notes`, and `Version History`, from which its `usage()`
prints. It already does, and that stays.

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

- Everything here is POSIX `sh`, with `#!/bin/sh`. The README supports Solaris
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
- The companion repository `dot_zsh` reaches the opposite conclusion for its
  own tree, because that tree is read only by zsh. This one is read by
  whatever `/bin/sh` is on the host, and the difference is not a matter of
  taste.

## 10. What `scripts/doc/POLICY` Lends

### 10.1 What Applies

- `install.sh` is bound by it in full: POSIX `/bin/sh`, the structured header,
  `usage()` printing that header, `check_commands` and `check_sudo`, the exit
  codes 0, 1, 126, and 127, and the `major.minor` version history in its own
  header.
- Its section 1.2.4 on naming: name a thing by what it is, not by a part of
  it, in the headers, the documents, and the commit messages.
- Its sections 1.6.2 to 1.6.4 on documents, as section 11 below states.
- Its section 1.8 on pull requests and branches: one purpose to a pull
  request, one commit to a coherent change, amended and force pushed with
  `--force-with-lease` rather than gaining a commit per remark, conflicts
  resolved by rebasing, and a revised branch reading as the change finally
  intended.
- Its section 1.5 on destructive operations and least privilege, which
  section 4 above states in the terms this repository needs.

### 10.2 What Does Not Apply to the Run

- The structured header block. Section 7.1 states what a sourced file carries.
- Per-file version numbers and `Version History` entries.
- `-h` and `-v`, usage output, and the exit code table. A plugin takes no
  options and is not invoked directly.
- `check_commands` as a gate. A plugin that needs a command tests for it where
  it is used and skips in silence, because refusing the whole run over an
  absent optional tool contradicts section 3.2.
- A test suite. What a change is checked against is section 12.

### 10.3 Where This Repository Does the Opposite

Its section 2.4 asks that ordinary log messages carry no timestamp. Here every
phase boundary carries one, for the reason section 6 gives. This is the one
deliberate contradiction, and it is not to be tidied away.

## 11. Versions and Documents

- The repository version is `<year>.<month>`, recorded in
  [`VERSIONS`](VERSIONS) and used for the Git tag. The Version History
  Guidelines at the foot of that file govern the entries.
- Files of the run carry no version of their own. `doc/VERSIONS` is their
  history.
- `install.sh` keeps its own `major.minor` version history, under the rules of
  `scripts/doc/POLICY` sections 1.7.1 and 1.7.2.
- A document written in Markdown takes `.md` when it is newly created, which
  is why this file is `doc/POLICY.md` while the policy of `scripts`, written
  earlier, is `doc/POLICY`.
- `LICENSE`, `COPYING`, `COPYING.LESSER`, and `VERSIONS` keep the names they
  have. A path here is a public URL, and no existing document is renamed to
  add or change an extension.
- `.gitattributes` gives `diff=markdown` to `*.md`, so that a diff hunk header
  names the section it falls in. It is a diff aid and nothing more. No file is
  given `linguist-language`, and `doc/VERSIONS`, `doc/COPYING`, and
  `doc/COPYING.LESSER` are excluded.
- Plain text is wrapped near 80 columns where that is practical. A URL, a
  command, a table, or a line that is clearer whole may exceed it.

## 12. Judging a Change

There is no test suite. A change to the run is checked by running it, and the
check is part of the change:

```sh
DRY_RUN=true PLUGINS="incremental_backup" ./exec/deferred-sync
```

with `JOBLOG` pointed somewhere writable, and the log read afterwards. A
change that touches a destructive path is proposed with what that log said.

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
- Is it safe when the same job runs again tomorrow, and when yesterday's has
  not finished?
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
