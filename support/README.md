# Support scripts

This directory hosts support (helper) scripts for Qt6.cr

## Contents

### `decide_binding_fast.cr`

Used to read (or generate) the "qt6.lock" file. This script is called from
`src/qt6/binding.cr`!

### `decide_binding_slow.cr`

Auto-detects which Qt6 version is available on the host system, and then chooses
the appropriate ready-built binding to use.  Used in tandem with
`decide_binding_fast.cr`:  If no "qt6.lock" file exists, it calls this script.
The reason for this split is that this code pulls in **bindgen** for the
detection part, making it quite slow to compile.

### `generate_bindings.cr`

(Re-)Generates the bindings for the configured Qt versions.  This script
automatically downloads and unpacks their sources from the internet, and then
generates all configured bindings using **bindgen**.  This mode is inherited from qt5.cr and untested
with Qt 6, whose `configure` wraps CMake.

With `--system`, it instead generates the binding for the Qt6 installed on the
system, as found by `qmake` (`qmake6`, `qmake-qt6` or `qmake`).  Set `QMAKE` to
choose a specific installation.  This needs neither `curl` nor `tar`.

#### Dependencies

* `curl`
* `tar` with support for `tar.xz` archives
* **bindgen** and its dependencies (See `lib/bindgen/README.md`)
