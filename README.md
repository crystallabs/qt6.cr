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
      * [Threads](#threads)
      * [Overriding virtual methods](#overriding-virtual-methods)
      * [Null pointers](#null-pointers)
      * [Downcasts](#downcasts)
      * [Differences to qt5.cr](#differences-to-qt5cr)
   * [Developer perspective](#developer-perspective)
      * [Generating the bindings](#generating-the-bindings)
      * [Qt versions](#qt-versions)
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

The bindings need bindgen 0.13.0 or newer, which needs LLVM and Clang 14 or
newer, CMake 3.12 or newer and Crystal 1.8 or newer.  Qt 6.4 or newer is
supported, see [Qt versions](#qt-versions).

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

If linking the tool fails with `ld: could not parse bitcode object file`, the
Xcode linker is older than Homebrew's LLVM, whose static libraries hold
bitcode.  Link LLVM dynamically instead: `BINDGEN_DYNAMIC=1 cmake ...`.

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

Objects created from Crystal are kept alive until Qt deletes them, like a
parent deletes its children, or until released.  The methods taking an object
out again without deleting it release it, so the GC may collect it once Crystal
drops it, like `Qt::Layout#remove_widget` and `#take_at`,
`Qt::ListWidget#take_item`, `Qt::StandardItemModel#take_item`,
`Qt::GraphicsScene#remove_item` or `Qt::MainWindow#take_central_widget`:

```crystal
layout.remove_widget(label) # Released
item = list.take_item(0)    # Released too
```

Others hand back only an index, like `Qt::TabWidget#remove_tab`, or take out
an object which may be used elsewhere still, like `Qt::Widget#remove_action`.
After these, `Qt::BindgenHelper.release` releases an object by hand:

```crystal
tabs.remove_tab(tabs.index_of(page))
Qt::BindgenHelper.release(page)
```

The methods are configured in `config/keep_alive.yml`.  An object given a
parent, by its constructor or `#parent=`, is kept alive too, as the parent owns
it: `Qt::Label.new("Stays alive", window)`.  Setting the parent to `nil`
releases it.  This is bindgen's `Qt` processor at work, for the classes
deriving from `QObject`, `QGraphicsItem` or `QGraphicsLayoutItem`.

## Threads

Qt objects belong to the thread that created them, and widgets to the main
thread.  Crystal's default runtime since 1.21 may resume a fiber in another OS
thread after a blocking call, like a slow file write, which breaks Qt: timers
fail and creating a window deadlocks.  So `src/qt6/main_thread.cr` keeps a
thread blocked in a call attached to its scheduler, as Crystal did before 1.21;
the fibers of the default context wait for the call instead of running
meanwhile.  Don't resize the default execution context: Qt must be called from
the main thread.  `-Dwithout_mt` disables execution contexts altogether, and
`-Dqt6_allow_mt` leaves them untouched.

`Qt::Thread`, `Qt::ThreadPool` and the locks are bound, but **a Qt thread
must not call into Crystal**: the Crystal runtime and its GC only know the
threads they start, so a Crystal method run from a Qt thread corrupts the
program.  Deleting a wrapped object counts, as its destructor calls into
Crystal to release it from `keep_alive`.  A thread started from Crystal runs Qt
code only, like the event loop `QThread::run` starts by default.  The signals
it emits are delivered in the main thread: the `on_x` connection methods
connect with the application object as the context of the connection, so with
the default `Qt::ConnectionType::AutoConnection`, a signal emitted in the main
thread runs the block at once, and one emitted in another thread queues the
block to the main event loop.  The connection methods take the connection
type as their argument, after the type arguments of an overloaded signal.
`Qt::ConnectionType::DirectConnection` runs the block on the emitting thread,
so don't use it for a signal a Qt thread emits:

```crystal
thread = Qt::Thread.new
thread.on_finished { puts "done" } # Called from the main event loop
thread.start
thread.quit
thread.wait

button.on_clicked(Qt::ConnectionType::QueuedConnection) { } # Run by the event loop, after the click
```

`QThread` and `QRunnable` are the one place a Crystal override of a virtual
method is unsupported: they get no C++ subclass, so a Crystal `run` is never
called (and a Crystal `Qt::Runnable` subclass can't be instantiated).  Use
Crystal's own `Thread` or fibers for Crystal work.  The locks exclude Qt
threads from Qt data: `mutex.lock`, `semaphore.acquire(2)`,
`condition.wait(mutex, Qt::DeadlineTimer.new(100))`.

## Overriding virtual methods

A Crystal subclass of a wrapped class overrides its virtual methods by
defining them, as `samples/virtual_override.cr` does; Qt calls the Crystal
method.  `super` calls the C++ implementation of the class the Crystal class
derives from, and so does the private `superclass` wrapper from any method:

```crystal
class Canvas < Qt::Widget
  def mouse_press_event(event : Qt::MouseEvent) : Void
    puts "pressed at #{event.pos.x}, #{event.pos.y}"
    super # Same as `superclass.mouse_press_event(event)`
  end
end
```

An exception raised in an override, or in the block of a signal, can't unwind
through the Qt code calling it: it goes to `Qt::BindgenHelper.on_exception`,
which prints it with its backtrace to the standard error by default, and Qt
receives a zero of the result type, `false` for an `event` override.  Replace
the handler to log or collect them:

```crystal
Qt::BindgenHelper.on_exception = ->(exception : Exception) { Log.error(exception: exception) { "In a Qt callback" } }
```

## Null pointers

A method returning a pointer to a Qt object returns `nil` when the pointer is
null, so its result is a union with `Nil`: `Qt::Widget#parent_widget` is a
`Qt::Widget?`, `Qt::ListWidget#item` a `Qt::ListWidgetItem?`, and so are
`Qt::AbstractItemView#model`, `Qt::StandardItem#child` or
`Qt::AnimationGroup#take_animation`.  Check the result, or unwrap it with
`not_nil!` where it can't be null.  Results Qt documents as never null, like
the menu bar a `Qt::MainWindow` creates on demand, the menu added to it, a
scroll area's viewport or a tree widget's header item, are configured as
non-nilable in `config/methods.yml` (bindgen's `nilable:` rule), which also
lets `nil` into pointer arguments Qt accepts null for, like
`view.model = nil` or `edit.validator = nil`:

```crystal
if item = list.item(row)
  puts item.text
end

menu = window.menu_bar.add_menu("File")
```

Only method results are nilable.  A method returning a reference, like
`Qt::Widget#font`, always returns an object, as does a cast like
`Qt::Widget#as_paint_device`.  The elements of a returned list, like
`Qt::StandardItemModel#take_row`, or the members of a tuple, like those of
`Qt::Gradient#stops`, are the objects themselves, and so is the argument a
signal or an overridden virtual method receives: a block of
`Qt::StandardItemModel#on_item_changed` gets a `Qt::StandardItem`, and an
override of `Qt::Widget#mouse_press_event` takes a `Qt::MouseEvent`, as
declared (see `samples/virtual_override.cr`).  This is bindgen's
`nilable_results` option, set in `qt.yml`.  A signal argument defaulting to
`nullptr` is the exception: a block of `Qt::Object#on_destroyed` gets a
`Qt::Object?`.

## Downcasts

A wrapper is of the class a method declares, so `Qt::Layout#item_at` returns a
`Qt::LayoutItem` and `Qt::Object#children` holds `Qt::Object`s.  `#to?`
casts to a subclass, returning `nil` when the object isn't one:

```crystal
if button = widget.to?(Qt::PushButton)
  button.flat = true
end
```

The cast is C++'s `dynamic_cast`, so the binding is built with RTTI
(`ext/Makefile`), as Qt itself is.

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

## Qt versions

Qt 6.4 or newer is supported.  The classes Qt added later are bound when the
binding is generated against a Qt that has them: `QNativeIpcKey` and
`QOperatingSystemVersionUnexported` (Qt 6.6), `QChildWindowEvent` (6.7),
`QChronoTimer` and `QPdfOutputIntent` (6.8), `QColorSpace::PrimaryPoints`
(6.9), `QQuaternion::Axis`, `QQuaternion::Axes`, `QBasicReadWriteLock` and
`QStyleOptionMenuItemV2` (6.11).  The configuration lists them under
conditions like `if_QT_VERSION_newer_or_6.6:`, which bindgen evaluates with
the Qt version `find_paths` found (also when `QMAKE` is set by hand), and the
specs test `Qt::QT_VERSION` at compile time.  Methods a newer Qt added simply
don't exist in a binding for an older Qt.

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

On macOS, export the variables of the [macOS](#macos) section first.  Without
`SDKROOT` the parser can't find the SDK's frameworks (`OpenGL/gl.h`) and
silently generates a broken binding, with constructors missing and `d_ptr`
accessors added, which then fails to compile; without `CPPFLAGS` compiling it
can't find `gc/gc.h`.

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
* bindgen instantiates the `QList`s the wrapped methods use, looking through
  Qt's typedefs of them: `QFileInfoList` is an `Enumerable(FileInfo)`,
  `QModelIndexList` an `Enumerable(ModelIndex)`.  `QItemSelection` derives
  from `QList<QItemSelectionRange>`, so `Qt::ItemSelection` is that list with
  the selection methods on top.
* Qt 6's `QPair` is `std::pair`, a container of `type: Pair`, exchanged as a
  `Tuple`: `UrlQuery#query_items` is an `Enumerable({String, String})`,
  `Gradient#stops` (`QGradientStops`) an `Enumerable({Float64, Color})`,
  `VariantAnimation#key_values` an `Enumerable({Float64, Variant})`, and the
  setters take an array of tuples: `gradient.stops = [{0.0, red}, {1.0, blue}]`.
* A model written in Crystal implements the pure virtual methods only, like
  `row_count(parent)` and `data(index, role)` of an `AbstractListModel`:
  bindgen makes the no-argument overloads a default argument splits off
  concrete, and wraps the methods `QAbstractListModel` overrides privately
  (`parent`, `columnCount`, `hasChildren`) through `QAbstractItemModel`.
  `StringListModel` can be subclassed too.  See `spec/qt/models_spec.cr`.
* `QAbstractTextDocumentLayout::PaintContext` and `Selection`,
  `QTextLayout::FormatRange`, `QTextEdit::ExtraSelection`,
  `QFormLayout::TakeRowResult`, `QTextOption::Tab`,
  `QInputMethodEvent::Attribute`, `QPainter::PixmapFragment`, `QFont::Tag`
  (Qt 6.7+), `QProcess::UnixProcessParameters` (Qt 6.6+),
  `QAbstractEventDispatcher::TimerInfo`, `QIconEngine::ScaledPixmapArgument`
  and `QTextStreamManipulator`, bare structs of Qt classes, are wrapped as
  classes with property methods: `Qt::TextDocumentLayoutPaintContext`,
  `Qt::TextLayoutFormatRange`, `Qt::TextEditExtraSelection.new(cursor:
  cursor, format: format)`, `form_layout.take_row(0).field_item`,
  `Qt::TextOptionTab.new(40.0, Qt::TextOption::TabType::RightTab)`,
  `Qt::PainterPixmapFragment.create(pos, source_rect)`,
  `input_method_event.attributes`, `font.feature_tags`, `stream <<
  Qt.q_set_field_width(6) << Qt.q_set_pad_char('*')`.  `QFont::Tag`'s
  `fromValue` and `fromString` return a `std::optional`, so they are dropped.
* `QSettings::registerFormat` is dropped, as its `ReadFunc` and `WriteFunc`
  are C function pointers; `Qt::Settings::Format::IniFormat` and the native
  format need none.
* `QTextFrame::iterator` and `QTextBlock::iterator` are Crystal `Iterator`s
  (`src/qt6/text_iterators.cr`): `frame.begin.each { |frame_or_block| }`,
  `block.begin.map(&.text)`.
* A Crystal `@[Flags]` enum defines `None` and `All` itself, so bindgen
  drops Qt's when they agree and renames the others `CppAll`:
  `QTreeWidgetItemIterator::IteratorFlags::All` (Qt's `0`, no filter) is
  `IteratorFlags::CppAll`, like `Style::SubControls::CppAll` (`SC_All`, all
  bits set) and `InputDevice::Capabilities::CppAll`.
  `Qt::TreeWidgetItemIterator` is an `Iterator`.
* `QHeaderView`'s protected `initialize()` is `#cpp_initialize`, as Crystal
  reserves the name for constructors, and `QWidget::raise` is `#raise_`, as
  it would shadow Crystal's `raise` in a widget written in Crystal
  (`config/methods.yml`).
* A `QString` taken by non-const reference or pointer is an out argument,
  returned with the result (bindgen's SPEC.md §2.2.5):
  `state, input, pos = validator.validate("42", 0)`, `validator.fixup("4 2")`
  returns the fixed string, `FileDialog.get_open_file_name(parent, caption,
  dir, filter)` returns `{file_name, selected_filter}`, `TextStream#read_line_into`
  `{Bool, String}` and `LockFile#lock_info` `{Bool, Int64, String, String}`.
  A validator or spin box written in Crystal returns the same tuple from its
  `validate`.  `QTextStream::setString` and `QBuffer::setBuffer` keep the
  pointer instead, and are ignored.
* The `QStyle` enum constants drop their prefixes:
  `Style::PixelMetric::ButtonMargin`.
* `QGraphicsWidget` derives from `QGraphicsObject` and `QGraphicsLayoutItem`:
  the wrapper has the layout item methods, and `#as_graphics_layout_item`
  casts it for `GraphicsLinearLayout#add_item` and friends.
* `QMap` and `QHash` are associative containers, exchanged as a `Hash`-like
  `Enumerable({K, V})` with `#[]`, `#[]?`, `#has_key?` and `#keys`:
  `StandardItemModel#item_data(index)` is one of `Int32` to `Variant`,
  `AbstractItemModel#role_names` of `Int32` to `Bytes`,
  `CalendarWidget#date_text_format` of `Date` to `TextCharFormat`, and the
  setters take a `Hash`: `model.set_item_data(index, {role => Qt.variant(x)})`.
* `std::optional<QFont>` (`FontComboBox#display_font`) has no mapping yet and
  is ignored.
* `QVector2D`, `QVector3D`, `QVector4D`, `QQuaternion`, `QRgba64`,
  `QPainterPath::Element`, `QPageRanges::Range` and
  `QColorSpace::PrimaryPoints` are copied structures passed by value, like
  `QPoint`, with property methods for their public fields: `element.x`,
  `range.from`.
* `Vector3D * Matrix4x4` and its mirror are dropped: Qt declares them as
  friends but deprecated their definitions in 6.1, which the cutoff hides.
  Use `Matrix4x4#map`.  Likewise `DateTime - DateTime`, whose
  `std::chrono::milliseconds` result bindgen can't convert: use
  `DateTime#msecs_to`.  `DateTime - Time::Span` works.
* `QMatrix3x3` (a `QGenericMatrix` instantiation) has no mapping, which drops
  `Matrix4x4#normal_matrix` and `Quaternion#to_rotation_matrix`.
* The QXmlStream classes return names, values and text as `QStringView`, which
  has no mapping (a view of a temporary `QString` would dangle in
  `RegularExpression#match`), so `src/qt6/xml_stream.cr` wraps the helpers of
  `ext/xml_helper.hpp`: `reader.name`, `attribute.value`,
  `reader.attributes.value("id")`.  `QXmlStreamAttributes` is a
  `QList<QXmlStreamAttribute>`, so `reader.attributes.map(&.name)` works.
* `QDataStream` streams `QString` and `QByteArray` through free operators,
  which bindgen doesn't wrap as methods: `src/qt6/data_stream.cr` adds
  `stream << "text"`, `stream.read(String)` and `stream.read(Int32)` over the
  wrapped `>>(Int32*)`.  The `>>` of a copied structure (`QPoint &`) is
  dropped.
* `std::chrono::nanoseconds` maps to `::Time::Span` like milliseconds, and so
  do Qt's typedefs of it like `QElapsedTimer::Duration`:
  `ChronoTimer.new(5.milliseconds)`, `ElapsedTimer#duration_elapsed`.
* `QKeyCombination` and `QPointingDeviceUniqueId` are copied structures:
  `KeyCombination.new(KeyboardModifiers::ControlModifier, Key::A)`.
  `QCalendar::YearMonthDay` too.
* `Qt::RegularExpressionMatchIterator` (`RegularExpression#global_match`) is
  an `Iterator(RegularExpressionMatch)`.
* `QJsonObject#[]` returns a `JsonValue` copy; `QJsonArray#[]` a
  `JsonValueRef`, whose `#assign!` writes through.  `QJsonObject#insert`
  returns a `JsonObjectIterator`.  Likewise `CborMap#insert` returns a
  `CborMapIterator` with `#key` and `#value` (a `CborValueRef`); the pair
  of references the iterator dereferences to isn't default constructible,
  which a pair container needs, so it is ignored.  `QCborTag` and
  `QCborNegativeInteger`, `enum class`es without enumerators, are `UInt64`:
  `CborValue.new(Qt::CborKnownTags::Url, value).tag` is `32`.
  `CborValue.new(Qt::CborValue::Type::Null)` replaces the `nullptr`
  constructor.  `QUtf8StringView` maps to `String` like `QAnyStringView`.
* `QStyleOptionHeaderV2` and `QStyleOptionMenuItemV2` keep their fields in
  bit-fields, which the property methods read and write:
  `option.text_elide_mode = Qt::TextElideMode::Middle`,
  `menu_item.mouse_down`.  `StyleHintReturnMask#region` and
  `StyleHintReturnVariant#variant` are properties too.
* A Crystal `Qt::IconEngine` subclass implements `paint` and `clone`
  (see `spec/qt/providers_spec.cr`).  `clone` is declared `IconEngine?`, as
  every pointer result is; an override returning `nil` hands C++ a null
  pointer.
* A Crystal editor creator derives from the abstract
  `Qt::ItemEditorCreatorBase`, implementing `create_widget(parent)` and
  `value_property_name` (`Bytes`), and registers with
  `ItemEditorFactory#register_editor(Qt::MetaType::Type::Int.to_i, creator)`.
  `QItemEditorCreator<T>` is a template and isn't bound.  `QRangeModel`
  (Qt 6.10+) only has template constructors over a C++ range and isn't bound.
* `QReadWriteLock` derives from `QBasicReadWriteLock` since Qt 6.11, like
  `QMutex` from `QBasicMutex`: the bases are listed so the methods are
  inherited.  The std-style `try_lock()` and `try_acquire()` aliases of
  `tryLock()` and `tryAcquire(n = 1)` would be the same Crystal methods, so
  bindgen drops them.  `try_lock_for` and friends are templates.
  `QMutexLocker` is a template in Qt 6 and isn't bound.
  `QException`, which only serves throwing across QtConcurrent threads, isn't
  bound: it would shadow `::Exception` inside the module.
* The meta-object system exchanges names as `const char *`, an `UInt8*`:
  `String.new(meta_object.class_name)`,
  `meta_object.index_of_property("text".to_unsafe)`.  `Qt::Widget.
  static_meta_object` is a copy of the class's `QMetaObject`, which the
  pointer comparison of `MetaObject#inherits` doesn't match: pass an
  instance's `meta_object`.  `QMetaObject::invokeMethod` and
  `QMetaMethod::invoke` take `QGenericArgument`s (type name and `void *`
  pairs) or are templates, so they are dropped;
  `Qt::MetaObject.invoke_method(object, "click")` (`ext/meta_helper.hpp`)
  invokes a method without arguments.  `MetaType::Type` keeps Qt's constant
  names, `MetaType::Type::QString`.
* Types without a mapping yet, like `std::optional` or the `QEvent`
  constructor tags, are ignored, which drops the methods using them.  A `bool *ok =
  nullptr` argument is `ok : Bool*? = nil`: `bits.to_u_int32(endian)`, or
  `transform.inverted(pointerof(invertible))` to learn the outcome.

## Future things to do

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
