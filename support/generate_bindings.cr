#!/usr/bin/env crystal

# This script downloads all sources of all supported Qt6 versions, and then
# proceed to generate all bindings for all configured platforms.
#
# With `--system`, it instead generates the binding for the Qt6 installed on
# this system, as found by `qmake`.  Set `QMAKE` to choose a specific one.

require "file_utils"
require "colorize"
require "ini"

require "../lib/bindgen/src/bindgen/find_path/generic_version"
require "../lib/bindgen/src/bindgen/variables"

# require "spoved/logger"
# spoved_logger :trace, bind: true, clear: true, dispatcher: :sync

configurations = [
  #      OS       LIBC   ARCH      Qt     Patch   Clang target triplet      Ptr  Endian
  {"linux", "gnu", "x86_64", "6.8", "0", "x86_64-unknown-linux-gnu", 8, "little"},
  #  {"linux", "gnu", "x86_64", "6.4", "0", "x86_64-unknown-linux-gnu", 8, "little"},
  #  {"darwin", "unknown", "aarch64", "6.8", "0", "arm64-apple-darwin23.0.0", 8, "little"},
]

TEMPDIR = File.expand_path("#{__DIR__}/../download_cache")

struct QtVersion
  getter name : String
  getter patch : String
  delegate to_s, to: @name

  def initialize(@name, @patch = "0")
  end

  def base_name
    "qt-everywhere-src-#{@name}.#{@patch}"
  end

  def download_urls
    ["https://download.qt.io/archive/qt/#{@name}/#{@name}.#{@patch}/single/#{base_name}.tar.xz",
     "https://download.qt.io/new_archive/qt/#{@name}/#{@name}.#{@patch}/single/#{base_name}.tar.xz"]
  end

  def path
    "#{TEMPDIR}/#{base_name}"
  end

  def archive_path
    path + ".tar.xz"
  end
end

# A platform to generate a binding for.
abstract class Platform
  # Name of the binding, like `linux-gnu-x86_64-qt6.8`.
  abstract def target : String

  # Environment variables for `config/find_paths.yml`.
  abstract def env : Hash(String, String)

  # Arguments to bindgen.
  abstract def args : Array(String)

  # Describes the Qt the binding is built from, for messages.
  abstract def to_s(io : IO) : Nil
end

class TargetPlatform < Platform
  getter os : String
  getter libc : String
  getter arch : String
  getter qt : QtVersion
  getter triple : String
  getter pointer_size : Int32
  getter endian : String

  def initialize(@os, @libc, @arch, qt, patch, @triple, @pointer_size, @endian)
    @qt = QtVersion.new(qt, patch)
  end

  def target : String
    "#{@os}-#{@libc}-#{@arch}-qt#{@qt}"
  end

  def env : Hash(String, String)
    {
      "QTDIR" => @qt.path,
      "QMAKE" => "#{@qt.path}/qtbase/bin/qmake",
      # "QT_INCLUDE_DIR" => Auto configured,
      "QT_LIBS_DIR"      => "#{@qt.path}/qtbase/libs",
      "TARGET_TRIPLE"    => @triple,
      "BINDING_PLATFORM" => target,
    }
  end

  def args : Array(String)
    [
      "qt.yml",
      "--var", "architecture=#{@arch}",
      "--var", "libc=#{@libc}",
      "--var", "os=#{@os}",
      "--var", "pointersize=#{@pointer_size}",
      "--var", "endian=#{@endian}",
      "--debug",
    ]
  end

  def to_s(io : IO) : Nil
    io << "Qt" << @qt << " for " << @triple
  end
end

# The Qt6 installed on this system, as reported by `qmake -query`.  Bindgen's
# built-in variables describe the platform, like in `decide_binding_slow.cr`.
class SystemPlatform < Platform
  getter qmake : String
  getter qt : String

  @query : Hash(String, String)

  def initialize
    candidates = ENV["QMAKE"]?.try { |path| [path] } || ["qmake6", "qmake-qt6", "qmake"]
    qmake = candidates.each do |name|
      if path = Process.find_executable(name)
        break path
      end
    end
    @qmake = qmake || abort "Can't find qmake: install Qt6 or set QMAKE"

    @query = Hash(String, String).new
    `#{Process.quote(@qmake)} -query`.each_line do |line|
      key, _, value = line.partition(':')
      @query[key] = value
    end

    version = @query["QT_VERSION"]? || abort "#{@qmake} -query didn't report QT_VERSION"
    abort "#{@qmake} is Qt #{version}, not Qt6" unless version.starts_with?("6.")
    @qt = version.split('.')[0..1].join('.') # "6.8.2" -> "6.8"
  end

  def target : String
    vars = Bindgen::Variables.builtin
    "#{vars["os"]}-#{vars["libc"]}-#{vars["architecture"]}-qt#{@qt}"
  end

  def env : Hash(String, String)
    {
      "QTDIR"            => @query["QT_INSTALL_PREFIX"],
      "QMAKE"            => @qmake,
      "QT_INCLUDE_DIR"   => @query["QT_INSTALL_HEADERS"],
      "QT_LIBS_DIR"      => @query["QT_INSTALL_LIBS"],
      "TARGET_TRIPLE"    => "", # Native build
      "BINDING_PLATFORM" => target,
    }
  end

  def args : Array(String)
    ["qt.yml", "--debug"]
  end

  def to_s(io : IO) : Nil
    io << "Qt" << @qt << " of " << @qmake
  end
end

def report(current, total, message)
  cur_s = (current + 1).to_s
  total_s = total.to_s

  step_s = "#{cur_s.ljust(total_s.size)}/#{total_s}".colorize.mode(:bold)
  puts "(#{step_s})  #{message}"
end

def report_step(message)
  puts "=> #{message}".colorize.mode(:bold)
end

def download_missing_qts(versions)
  # Test a model where URLs are always tried to be downloaded, but if they're complete
  # the curl call will be a no-op. This might be more user friendly than just using
  # existence of file to assume that the file has been downloaded in full, which then
  # causes unclear tar errors if file is invalid or incomplete.
  urls = versions
    # .reject{|v| File.file? v.archive_path}
    .map { |v| v.download_urls }

  if urls.empty?
    report_step "All Qt sources already present"
    return
  end

  # report_step "Downloading missing Qt sources (#{versions.map{|v|v.name}.join(", ")})"
  report_step "Verifying and/or downloading Qt sources (#{versions.map { |v| v.name }.join(", ")})"

  urls.each do |version_urls|
    version_urls.each_with_index do |url, idx|
      arguments = ["-C-", "--fail", "--remote-name-all", "--location", url]

      break if Dir.cd TEMPDIR do
                 report(idx, version_urls.size, "Trying: curl #{arguments}")
                 system("curl", arguments)
               end
    end
  end
end

def unpack_qts(versions)
  files = versions
    .reject { |v| Dir.exists? v.path }
    .map { |v| v.archive_path }

  if files.empty?
    report_step "All Qt sources already unpacked"
    return
  end

  report_step "Unpacking Qt sources"
  files.each_with_index do |file, idx|
    switches = "-xf"
    report(idx, files.size, "Unpacking: tar -C #{TEMPDIR} #{switches} #{file}")
    system("tar", ["-C", TEMPDIR, switches, file])
  end
end

def get_qt_modules_from_gitmodules(version)
  # This is actually how they're aggregating which modules exist in `qt.pro`
  modules_file = "#{version.path}/.gitmodules"

  if File.exists? modules_file
    data = INI.parse File.read(modules_file)
    data
      .reject { |_, v| v["qt"]? == "false" }
      .map { |k, _| k[/submodule "qt(.*)"/, 1]? }
  end
end

def get_qt_modules_from_qtpro(version)
  # For Qt5.5 and below
  pro_file = "#{version.path}/qt.pro"

  if File.exists? pro_file
    File.read_lines(pro_file)
      .select(/^addModule\(qt/)
      .map { |x| x[/addModule\(qt([^,)]+)/, 1]? }
      .to_a
  end
end

def get_qt_modules(version) : Array(String)
  modules = get_qt_modules_from_gitmodules(version)
  modules ||= get_qt_modules_from_qtpro(version)

  if modules
    modules
      .compact
      .select { |name| Dir.exists?("#{version.path}/qt#{name}") }
  else
    Array(String).new
  end
end

# NOTE: Untested with Qt 6, whose `configure` wraps CMake.  The `--system` mode
# below is the supported way to generate a binding.
def configure_qts(versions)
  keep_modules = {"base"}
  list = versions.reject { |v| Process.find_executable("#{v.path}/qtbase/bin/qmake") }

  if list.empty?
    report_step "All Qt sources already configured"
    return
  end

  report_step "Configuring Qt versions"
  list.each_with_index do |qt, idx|
    report(idx, list.size, "Configuring Qt#{qt}")

    skip_modules = get_qt_modules(qt).reject { |x| keep_modules.includes? x }
    skip_args = skip_modules.flat_map { |x| ["-skip", x] }

    Dir.cd qt.path do
      # Build QMake of this version
      system(
        "./configure",
        [
          "-opensource", "-confirm-license",
          "-nomake", "examples",
          "-nomake", "tests",
          "-nomake", "tools",
          "-prefix", "#{qt.path}/qtbase",
        ] + skip_args
      )

      unless $?.success?
        STDERR.puts "Failed to configure Qt#{qt} in #{qt.path} - Abort."
        exit 2
      end
    end

    # Use QMake to generate all missing include files
    system("make", ["-C", qt.path, "qmake_all"])

    unless $?.success?
      STDERR.puts "Failed to generate headers for Qt#{qt} in #{qt.path} - Abort."
      exit 2
    end
  end
end

# Kick off
if system_qt = ARGV.includes?("--system")
  platform = SystemPlatform.new
  report_step "Using Qt#{platform.qt} of #{platform.qmake}"
  platforms = [platform] of Platform
else
  FileUtils.mkdir_p(TEMPDIR)
  targets = configurations.map { |x| TargetPlatform.new(*x) }
  platforms = targets.map(&.as(Platform))
  versions = targets.map(&.qt).uniq

  # Download and unpack Qt sources
  download_missing_qts(versions)
  unpack_qts(versions)
  configure_qts(versions)
end

# Run bindgen for all configured platforms, or the system one
report_step(system_qt ? "Generating the binding for the system Qt6" : "Generating bindings for all platforms")
platforms.each_with_index do |platform, idx|
  report(idx, platforms.size, "Generating #{platform.target}")
  # Run bindgen
  bindgen = Process.run(
    command: "lib/bindgen/tool.sh",
    args: platform.args,
    env: platform.env,
    shell: false,
    output: STDOUT,
    error: STDERR,
  )

  unless bindgen.success?
    STDERR.puts "Failed to build #{platform.target} using #{platform} - Abort."
    exit 1
  end
end
