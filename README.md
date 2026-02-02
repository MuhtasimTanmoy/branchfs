# BranchFS

BranchFS is a FUSE-based filesystem that provides lightweight, atomic branching capabilities on top of any existing filesystem. Designed for speculative execution workflows, it enables isolated workspaces with commit-to-root and abort semantics.

## Features

| Feature | Description |
|---------|-------------|
| Fast Branch Creation | O(1) branch creation with copy-on-write semantics |
| Commit to Root | Changes apply directly to the base filesystem |
| Atomic Abort | Instantly invalidates branch, sibling branches unaffected |
| Atomic Commit | Applies changes and invalidates all branches atomically |
| mmap Invalidation | Memory-mapped files trigger SIGBUS after commit/abort |
| Portable | Works on any underlying filesystem (ext4, xfs, nfs, etc.) |

## Architecture

BranchFS operates as a single daemon process managing multiple mount sessions. The daemon starts automatically on the first mount and exits when the last mount is removed. Each branch provides an isolated view of the filesystem while sharing unchanged content with its parent.

```
┌─────────────────────────────────────────────────────────────────────┐
│  Namespace 1                 Namespace 2                Namespace 3 │
│  Agent 1                     Agent 2                    Agent 3     │
│                                                                     │
│  /mnt/workspace              /mnt/workspace             /mnt/...    │
│  (branch: spec1)             (branch: spec2)            (spec3)     │
│                                                                     │
└────────┬─────────────────────────────┬─────────────────────┬────────┘
         │                             │                     │
         ▼                             ▼                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                    BranchFS Daemon (FUSE)                           │
│                                                                     │
│         Manages branch hierarchy, copy-on-write storage,            │
│         and atomic commit/abort operations                          │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│      Base Directory                    Branch Storage               │
│      (read-only reference,             (copy-on-write deltas)       │
│       commit target)                                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Branch Hierarchy

Branches form a tree rooted at the main branch. Each branch inherits content from its parent and stores only modified files.

```
base (~/project)
│
└── main
    ├── spec1
    │   └── spec1a
    └── spec2
```

## Prerequisites

- Linux with FUSE support
- libfuse3 development libraries
- Rust toolchain (1.70 or later)

### Installing Dependencies

**Debian/Ubuntu:**
```bash
sudo apt install libfuse3-dev pkg-config
```

**Fedora:**
```bash
sudo dnf install fuse3-devel pkg-config
```

**Arch Linux:**
```bash
sudo pacman -S fuse3 pkg-config
```

## Building

```bash
git clone https://github.com/user/branchfs.git
cd branchfs
cargo build --release
```

The binary is located at `target/release/branchfs`.

## Usage Examples

### Basic Workflow

```bash
# Mount filesystem (auto-starts daemon, starts on main branch)
branchfs mount --base ~/project /mnt/workspace

# Create a speculative branch and switch to it
branchfs create experiment -m /mnt/workspace -p main

# Work in the branch (files modified here are isolated)
cd /mnt/workspace
echo "new code" > feature.py

# Commit changes to base (switches back to main, stays mounted)
branchfs commit /mnt/workspace

# Or abort to discard (switches back to main, stays mounted)
branchfs abort /mnt/workspace

# Unmount when done (daemon exits when last mount removed)
branchfs unmount /mnt/workspace
```

### Nested Branches

```bash
# Mount and create hierarchy
branchfs mount --base ~/project /mnt/workspace
branchfs create level1 -m /mnt/workspace -p main
branchfs create level2 -m /mnt/workspace -p level1

# Now on level2, work in it
echo "deep change" > /mnt/workspace/file.txt

# Commit from level2 applies: level2 + level1 → base, switches to main
branchfs commit /mnt/workspace
```

### Parallel Speculation (Multiple Mount Points)

```bash
# Mount main workspace
branchfs mount --base ~/project /mnt/main

# Create sibling branches with separate mount points
branchfs create approach-a -m /mnt/approach-a -p main
branchfs create approach-b -m /mnt/approach-b -p main

# Work in parallel...

# Commit one approach (invalidates all other branches)
branchfs commit /mnt/approach-a

# approach-b mount now receives ESTALE on operations
```

## Semantics

### Commit

Committing a branch applies the entire chain of changes to the base filesystem:

1. Changes are collected from the current branch up through its ancestors
2. Deletions are applied first, then file modifications
3. Global epoch increments, invalidating all branches
4. **Mount automatically switches to main branch** (stays mounted)
5. Memory-mapped regions trigger `SIGBUS` on next access

### Abort

Aborting discards the entire branch chain without affecting the base:

1. The entire branch chain (current branch up to main) is discarded
2. Sibling branches continue operating normally (no epoch change)
3. **Mount automatically switches to main branch** (stays mounted)
4. Memory-mapped regions in aborted branches trigger `SIGBUS`

### Unmount

Unmounting discards the current branch and removes the mount:

1. **Only the current branch is discarded** (single-level abort)
2. Parent branch chain remains intact in storage
3. The mount is removed from daemon management
4. The daemon automatically exits when the last mount is removed

## CLI Reference

### mount

Mount the filesystem on main branch. The daemon starts automatically on the first mount and exits when the last mount is removed.

```bash
branchfs mount --base <BASE_DIR> [--storage <STORAGE_DIR>] <MOUNT_POINT>
```

| Option | Description |
|--------|-------------|
| `--base` | Source directory to branch from (required on first mount) |
| `--storage` | Directory for branch storage (default: `/var/lib/branchfs`) |
| `<MOUNT_POINT>` | Where to mount the filesystem |

### create

Create a new branch from an existing parent, optionally switching an existing mount to it.

```bash
branchfs create <NAME> [--parent <PARENT>] [--mount <MOUNT_POINT>] [--storage <STORAGE_DIR>]
```

| Option | Description |
|--------|-------------|
| `<NAME>` | Name for the new branch |
| `--parent`, `-p` | Parent branch name (default: `main`) |
| `--mount`, `-m` | Mount point to switch to the new branch |
| `--storage` | Directory for branch storage (default: `/var/lib/branchfs`) |

### commit

Commit all changes from the current branch chain to the base filesystem. The mount switches to main and stays mounted.

```bash
branchfs commit <MOUNT_POINT> [--storage <STORAGE_DIR>]
```

| Option | Description |
|--------|-------------|
| `<MOUNT_POINT>` | Mount point of the branch to commit |
| `--storage` | Directory for branch storage (default: `/var/lib/branchfs`) |

### abort

Abort the entire branch chain, discarding all uncommitted changes. The mount switches to main and stays mounted.

```bash
branchfs abort <MOUNT_POINT> [--storage <STORAGE_DIR>]
```

| Option | Description |
|--------|-------------|
| `<MOUNT_POINT>` | Mount point of the branch to abort |
| `--storage` | Directory for branch storage (default: `/var/lib/branchfs`) |

### list

List all branches and their parent relationships.

```bash
branchfs list [--storage <STORAGE_DIR>]
```

| Option | Description |
|--------|-------------|
| `--storage` | Directory for branch storage (default: `/var/lib/branchfs`) |

### unmount

Unmount and discard only the current branch (single-level). Parent branches remain in storage. The daemon automatically exits when the last mount is removed.

```bash
branchfs unmount <MOUNT_POINT> [--storage <STORAGE_DIR>]
```

| Option | Description |
|--------|-------------|
| `<MOUNT_POINT>` | Mount point to unmount |
| `--storage` | Directory for branch storage (default: `/var/lib/branchfs`) |

