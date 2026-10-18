# Qt6 bindings for Crystal

Bindings for the Qt6 Framework using [bindgen](https://github.com/crystallabs/bindgen).
This is the Qt 6 successor of [qt5.cr](https://github.com/crystallabs/qt5.cr).

# Table of Contents

<!--ts-->
   * [Project Goals](#project-goals)
   * [Installation](#installation)
      * [Additional development dependencies](#additional-development-dependencies)
      * [macOS](#macos)
   * [User perspective](#user-perspective)
      * [Sample Crystal-Qt6 code](#sample-crystal-qt6-code)
      * [Locale](#locale)
      * [String lists](#string-lists)
      * [Object lifetime](#object-lifetime)
      * [Differences to qt5.cr](#differences-to-qt5cr)
   * [Developer perspective](#developer-perspective)
      * [Generating the bindings](#generating-the-bindings)
      * [Deprecated Qt API](#deprecated-qt-api)
      * [Naming scheme](#naming-scheme)
      * [(Re)generating the binding for the system's Qt6](#regenerating-the-binding-for-the-systems-qt6)
      * [(Re)generating a specific Qt6 binding version](#regenerating-a-specific-qt6-binding-version)
      * [Type rules for Qt 6](#type-rules-for-qt-6)
      * [Future things to do](#future-things-to-do)
   * [Platform Support](#platform-support)
   * [Contributing](#contributing)
      * [Contributors](#contributors)
   * [License](#license)
      * [A note on Qt's license](#a-note-on-qts-license)
<!--te-->

# Project Goals

* **Just Works™** - Drop the dependency into a project, and use it
* Providing an API that feels native to Crystal
* Focus on the GUI components (i.e. `QtCore`, `QtGui`, `QtWidgets`)

# Installation

Add the shard to your `shard.yml`.  The generated bindings for the platforms
CI builds (see [Platform Support](#platform-support)) are included, and
compiled on first use, which needs a C++ compiler, `make` and the Qt
development files.  On other platforms, generate the binding for your system's
Qt first, see [Generating the bindings](#generating-the-bindings).

```yaml
dependencies:
  qt6:
    github: crystallabs/qt6.cr
```

Your users will be required to have the Qt6 libraries on their system because
this project defaults to binding to Qt libraries dynamically.  (See more on this
under License below.)

## Additional development dependencies

Using your system's package manager (LLVM, Clang and CMake are only needed to
generate a binding):

* **ArchLinux** `pacman -S qt6-base gc cmake llvm clang pcre2`
* **Debian/Ubuntu/Devuan** `apt-get install qt6-base-dev qt6-base-dev-tools libgc-dev cmake llvm-dev clang libclang-dev libpcre2-dev libz-dev libstdc++-dev`
* **macOS** `brew install qt bdw-gc llvm cmake`

The bindings need bindgen 0.11.1 or newer, which needs LLVM and Clang 14 or
newer, CMake 3.12 or newer and Crystal 1.8 or newer.  Qt 6.4 or newer is
supported.

If linking Crystal programs fails with undefined references like
`__isoc23_strtol` from `libgc.a`, your Crystal package bundles a `libgc` built
for a newer glibc than your system has (e.g. recent Crystal on Debian 12).
Link against the system's `libgc` instead:

```sh
export CRYSTAL_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
```

## macOS

Homebrew's Qt is built as frameworks: its headers live in
`/opt/homebrew/lib/Qt*.framework/Headers`, which the bindings find through
`qmake6` and `pkg-config`.  Building the bindings needs the SDK and Homebrew's
include and library directories:

```sh
export SDKROOT="$(xcrun --show-sdk-path)"
export CPPFLAGS=-I/opt/homebrew/include
export LIBRARY_PATH=/opt/homebrew/lib
export PKG_CONFIG_PATH=/opt/homebrew/opt/qt/lib/pkgconfig
```

Build bindgen's clang tool with Homebrew's LLVM:

```sh
cd lib/bindgen/clang && cmake -DLLVM_DIR=/opt/homebrew/opt/llvm/lib/cmake/llvm . && make
```

If Homebrew's `qt@5` is installed as well, make sure `qmake6` (not `qt@5`'s
`qmake`) is found, or set `QMAKE=/opt/homebrew/opt/qt/bin/qmake6`.

# User perspective

## Sample Crystal-Qt6 code

Have a look in [samples/](samples/)!

A short **Hello World** snippet looks like this:

```crystal
require "qt6"

qApp = Qt::Application.new

label = Qt::Label.new "Hello from Crystal/Qt!"
label.show

Qt::Application.exec
```

![hello-qt](images/hello-qt.png)

## Locale

By default Qt sets the locale to the system locale when an application
class (like `Qt::Application`) is instantiated. However, this causes
stdlib Crystal functions like `to_f` to behave unexpectedly, e.g.,
using a different character as decimal separator (also see the discussion
of this [PR](https://github.com/Papierkorb/qt5.cr/pull/51)).
Therefore, in contrast to the behaviour of the C++ classes of Qt,
`qt6.cr` resets the numeric locale to "C" after creating an
application class instance (this follows an [advice from Qt
itself](https://doc.qt.io/qt-6/qcoreapplication.html#locale-settings)).

## String lists

`QStringList` is a `QList<QString>`, wrapped as `Qt::StringList`: methods
taking one accept any `Enumerable(String)`, and methods returning one return a
`Qt::StringList`, which is an `Indexable(String)`:

```crystal
combo_box.add_items(["one", "two"])
names = Qt::Dir.new(".").entry_list(["*.cr"], Qt::Dir::Filters::Files)
names.sort(Qt::CaseSensitivity::CaseInsensitive) # In place
names.filter(".cr").join(", ")
```

Qt's own `QStringList` methods are bound: `#sort(cs = CaseSensitive)`,
`#remove_duplicates`, `#filter`, `#replace_in_strings`, `#contains(str, cs)`,
`#index_of` and `#last_index_of` (also taking a `Qt::RegularExpression`), and
`#join`.  `Enumerable`'s methods come before Qt's in Crystal's lookup, so
`#join` is `Enumerable#join` (with the same result), while `#sort` is Qt's
in-place one, as `Enumerable` has no `#sort`: use `#to_a.sort` for a sorted
`Array`.

`Qt::Polygon` and `Qt::PolygonF` are lists of `Qt::Point` and `Qt::PointF`
the same way: `polygon << Qt::Point.new(1, 2)`, `polygon.to_a`.

## Object lifetime

Objects created from Crystal are collected by the GC once Crystal no longer
refers to them.  Qt's references, like a layout's to its widgets, are invisible
to the GC.  So the methods by which Qt takes ownership of an object or keeps a
pointer to it, like `Qt::Layout#add_widget`, `Qt::ListWidget#add_item`,
`Qt::MainWindow#central_widget=`, `Qt::AbstractItemView#model=` or
`Qt::PushButton#menu=`, keep their arguments alive:

```crystal
layout.add_widget Qt::Label.new("Stays alive")
view.model = Qt::StandardItemModel.new # Stays alive too
button.menu = Qt::Menu.new             # And so does this
```

They're kept alive until passed to `Qt::BindgenHelper.release`, e.g. after
taking a widget out again:

```crystal
layout.remove_widget(label)
Qt::BindgenHelper.release(label)
```

The methods are configured in `config/keep_alive.yml`.  Giving an object a
parent by its constructor or `#parent=` doesn't keep it alive: keep a
reference to it, or add it by one of these methods.

## Differences to qt5.cr

The Crystal API follows Qt 6's C++ API, so code written for qt5.cr may need
these changes:

* Sizes and indices are `qsizetype`, which is `Int64` on 64-bit platforms, where
  Qt 5 had `Int32`: e.g. `Qt::Dir#count` or `Qt::ListWidget#count` of a
  `QList`-backed widget.
* `QVector` is an alias of `QList`, so there's only one container type.
* `Qt::DesktopWidget` and `Qt::DeferredDeleteEvent` are gone, like in Qt 6.
* `Qt::MouseEvent` inherits `Qt::SinglePointEvent` and `Qt::PointerEvent`, which
  Qt 6 added.  `Qt::MouseEvent#pos` and `#buttons` work like before.
* Signal overloads Qt 6 removed, like `QComboBox::currentIndexChanged(QString)`,
  are gone with it.
* `Qt::Locale::Territory` replaces `Qt::Locale::Country`.

# Developer perspective

## Generating the bindings

If you want to work on `qt6.cr` itself or you want to generate bindings for new
versions, run the generation yourself as described below.

**Important**: For this you'll also have to meet the dependencies of bindgen.
See `lib/bindgen/README.md` and `lib/bindgen/clang/README.md`.

The generated `src/qt6/binding/binding_*.cr` and `ext/qt_binding_*.cpp` of the
platforms CI builds are committed.  CI regenerates them on every run, warns
when the committed ones are out of date, and uploads the fresh ones as the
`binding-<platform>` workflow artifact: download it and commit its two files.

## Deprecated Qt API

The bindings don't wrap deprecated Qt API.  The headers are parsed and the C++
wrappers built as C++17 with `QT_DISABLE_DEPRECATED_BEFORE=0x060800` (see
`qt.yml` and `ext/Makefile`), which hides the declarations Qt deprecated up to
6.8.  Qt 6.5 and later call this macro `QT_DISABLE_DEPRECATED_UP_TO`, but
still read the old name, which Qt 6.0 to 6.4 only know.  What Qt deprecated
later, and the deprecated virtual functions it keeps visible, are declared
`[[deprecated]]`, which bindgen's `ignore_deprecated: true` drops overload by
overload, so a non-deprecated overload like `QSpinBox::valueChanged(int)`
stays.

Building the bindings should thus print no `-Wdeprecated-declarations`
warnings, and CI fails if it does.

## Naming scheme

As `qt6.cr` supports different versions of Qt on different platforms,
generated bindings follow a naming scheme.  The scheme contains 4 components
as follows:

`KERNEL - LIB_C - ARCH - qtVERSION`, e.g. `linux-gnu-x86_64-qt6.8`

Where:

* `KERNEL` is the OS kernel, e.g. `linux`, `darwin`, `windows`
* `LIB_C` is the lib C name, e.g. `gnu`, `musl`, `win32`, or `unknown` on macOS
* `ARCH` is the architecture, e.g. `x86_64`, `aarch64`
* `VERSION` is the Qt version, e.g. `6.4`, `6.8`, `6.11`

The naming scheme is not strictly enforced.  However, it should always end with
`-qtVERSION`!

## (Re)generating the binding for the system's Qt6

To generate the binding for the Qt6 installed on your system, run from the
`qt6.cr` directory:

```sh
crystal support/generate_bindings.cr -- --system
```

It asks `qmake` (`qmake6`, `qmake-qt6` or `qmake`, or `$QMAKE` if set) where Qt
is installed and which version it is, and names the binding after the host, e.g.
`linux-gnu-x86_64-qt6.8` or `darwin-unknown-aarch64-qt6.11`.

Then verify with `crystal spec`, and build the samples.

`support/generate_bindings.cr` without `--system` downloads and configures Qt
sources to build bindings for other versions.  This mode is untested with
Qt 6.

## (Re)generating a specific Qt6 binding version

1. Decide which version of Qt to use, and build the scheme (See above)
2. Export the binding scheme: `export BINDING_PLATFORM=linux-gnu-x86_64-qt6.8`
3. If you're not using your system's Qt: `export QMAKE=/path/to/qmake6`
4. Run bindgen as usual: `lib/bindgen/tool.sh qt.yml --stats`
5. Verify with `crystal spec`

## Type rules for Qt 6

`config/types.yml` holds the rules Qt 6 needs beyond bindgen's built-in types,
see the comments there:

* Class-local typedefs like `QPoint::Representation` (Qt 6.10+, a
  `QCheckedInt<int>`) or `QPalette::ResolveMask` get `alias_for` rules, so the
  structures can be copied and the methods wrapped.
* `char32_t`, which the `QLocale::toString` overloads take, and `char16_t`,
  which `QTextStream#<<` takes, map to `Char` like `QChar`.
* `std::chrono::milliseconds` and `std::chrono::seconds` map to `::Time::Span`
  (qualified, as `Qt::Time` shadows `Time` inside the module):
  `timer.start(2.seconds)`, `lock_file.try_lock(10.milliseconds)`.
* `QStringList` and `QVariantList` are aliases of `QList<QString>` and
  `QList<QVariant>`, so methods take any `Enumerable(String)`:
  `combo_box.add_items(["a", "b"])`.  `QList<QString>` and
  `QListSpecialMethods<QString>`, which holds the `QStringList` methods, are
  listed as classes, so the wrapper `Qt::StringList` has those methods.  The
  overloads taking `QStringView`, `QLatin1StringView` or a string matcher are
  dropped, as the Crystal `String` maps to `QString`.
* `QVariant` maps to `Qt::Variant`, which exchanges the types Qt knows in
  their native form, so Qt can display, sort and store them: `Nil`, `Bool`,
  `Int32`, `UInt32`, `Int64`, `UInt64`, `Float32`, `Float64`, `Char`, `String`,
  `Bytes`, `Array(String)` (`QStringList`), `Point`, `PointF`, `Size`, `SizeF`,
  `Rect` and `RectF`.  Any other Crystal value is wrapped as is and comes back
  unchanged; a `QVariant` of another Qt type unpacks as unknown (`#to?`
  returns `nil`).  See `Qt::Variant`.
* `QByteArray` maps to `Bytes`, copied in both directions like `QString`:
  `String.new(process.read_all_standard_output)`, `mime_data.set_data(type,
  bytes)`.  `QList<QByteArray>` is an `Enumerable(Bytes)`.  `QByteArrayView`
  maps to `Bytes` as well, like `QAnyStringView` to `String`:
  `CryptographicHash.hash(bytes, algorithm)`.
* bindgen instantiates the `QList`s the wrapped methods use, resolving the
  aliases it knows, so Qt's other list typedefs get `alias_for` rules too:
  `QFileInfoList` is an `Enumerable(FileInfo)`, `QModelIndexList` an
  `Enumerable(ModelIndex)`.  `QItemSelection` derives from
  `QList<QItemSelectionRange>`, so `Qt::ItemSelection` is that list with the
  selection methods on top.
* `QAbstractListModel` and `QAbstractTableModel` override `parent`,
  `columnCount` and `hasChildren` privately; `src/qt6/abstract_list_model.cr`
  and `abstract_table_model.cr` give their `Impl` classes those, as Qt does.
  `StringListModel` can't be subclassed from Crystal (`sub_class: false`),
  as bindgen would forward those private overrides; subclass
  `AbstractListModel` instead.
* `QAbstractTextDocumentLayout::PaintContext`, a bare struct, is ignored, which
  drops `draw`, the layout's pure virtual: the class gets `sub_class: false`,
  as a subclass from Crystal would stay abstract in C++.  Use
  `PlainTextDocumentLayout`, or `TextDocument#document_layout`.
* `QTreeWidgetItemIterator::IteratorFlags` maps as a plain enum, as Qt's
  `All = 0` is what a Crystal `@[Flags]` enum calls `None`; its constants still
  combine with `|`.  `Qt::TreeWidgetItemIterator` is an `Iterator`.
* `QHeaderView`'s protected `initialize()` is dropped, as Crystal reserves the
  name for constructors.
* Types without a mapping yet, like `QFont::Tag`, `std::chrono::nanoseconds` or
  the `QEvent` constructor tags, are ignored, which drops the methods using them.

## Future things to do

* Forwarding `qHash()` of wrapped types (to `Object#hash`)
* Integration with **LibEvent**: Right now, Qt blocks the whole thread.
* The rest of the billion Qt classes of interest
* Integration for the `Qt Designer` UI designer
* Integration for `Qt Linguist`
  * Localization/Translation for your applications!
* UI test library, with adapter for `spec`
* Automated copy (and adaption) of the Qt documentation, for easy Crystal-specific docs
  * The Qt Docs license should allow this if done correctly

# Platform Support

| System                   | Status           | Qt version | Notes                       |
| ------------------------ | ---------------- | ---------- | --------------------------- |
| Ubuntu 24.04             | **Works**        | 6.4        | CI, with LLVM 14 and 18     |
| macOS (Homebrew, arm64)  | **Works**        | 6.11       | CI                          |
| ArchLinux                | Should work      | 6.x        | Help wanted                 |
| Windows                  | Help wanted      | ?          |                             |

# Contributing

1. Open a new issue on the project to discuss what you're going to do and possibly receive comments
2. Read bindgen's `STYLEGUIDE.md` for some tips
3. Then do the rest, PR and all.  You know the drill :)

## Contributors

- [Papierkorb](https://github.com/Papierkorb) Stefan Merettig - creator of qt5.cr
- [docelic](https://github.com/docelic) Davor Ocelic - qt6.cr

# License

The Qt bindings, including the generated and manually-written parts, are subject
to the MPL-2 license.  You can find a copy attached of the full license text in
the `LICENSE` file.

This project claims no copyright on the `Qt framework` or of any of its
trademarks, source, or any other assets.

## A note on Qt's license

A common misconception is that you have to pay for Qt to use it in closed-source
applications.

This project assumes you'll link to Qt dynamically.  In this case, you can use
**Qt free of charge** including for **closed-source, commercial applications**
under the terms of the **LGPL**.

You can build closed-source applications using Crystal, this shard, and Qt
**for free**.

**Note**: This section is to combat this misconception, the authors of `qt6.cr`
are in no way responsible to check if the same terms apply **in your jurisdiction**.
