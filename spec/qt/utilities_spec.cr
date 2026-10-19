require "../spec_helper"

describe Qt::Uuid do
  it "creates and parses ids" do
    Qt::Uuid.new.null?.should be_true
    uuid = Qt::Uuid.create_uuid
    uuid.null?.should be_false
    uuid.version.should eq(Qt::Uuid::Version::Random)
    uuid.variant.should eq(Qt::Uuid::Variant::Dce)
    text = uuid.to_string
    text.should match(/^\{[0-9a-f-]{36}\}$/)
    uuid.to_string(Qt::Uuid::StringFormat::WithoutBraces).size.should eq(36)
    Qt::Uuid.from_string(text).should eq(uuid)
    Qt::Uuid.new(text).should eq(uuid)
    Qt::Uuid.from_rfc4122(uuid.to_rfc4122).should eq(uuid)
    uuid.to_rfc4122.size.should eq(16)
    Qt::Uuid.new("not a uuid").null?.should be_true
    (Qt::Uuid.create_uuid != uuid).should be_true
  end
end

describe Qt::UrlQuery do
  it "holds query items" do
    query = Qt::UrlQuery.new("a=1&b=two")
    query.empty?.should be_false
    query.has_query_item("a").should be_true
    query.query_item_value("b").should eq("two")
    query.add_query_item("c", "three four")
    query.query.should eq("a=1&b=two&c=three four")
    query.to_string(Qt::Url::ComponentFormattingOptions::FullyEncoded).should eq("a=1&b=two&c=three%20four")
    query.add_query_item("a", "2")
    query.all_query_item_values("a").to_a.should eq(["1", "2"])
    query.remove_all_query_items("a")
    query.has_query_item("a").should be_false
    query.remove_query_item("b")
    query.query.should eq("c=three four")
    query.add_query_item("a", "2")
    query.query_items.to_a.should eq([{"c", "three four"}, {"a", "2"}])
    query.query_items = [{"k", "v"}]
    query.query.should eq("k=v")

    url = Qt::Url.new("http://example.org/path?x=1")
    Qt::UrlQuery.new(url).query_item_value("x").should eq("1")
  end
end

describe Qt::VersionNumber do
  it "compares versions" do
    v1 = Qt::VersionNumber.new(6, 4)
    v2 = Qt::VersionNumber.new(6, 11, 1)
    v1.major_version.should eq(6)
    v2.micro_version.should eq(1)
    v2.segments.to_a.should eq([6, 11, 1])
    v2.to_string.should eq("6.11.1")
    (v1 < v2).should be_true
    (v2 >= v1).should be_true
    Qt::VersionNumber.compare(v1, v2).should be < 0
    v1.is_prefix_of(Qt::VersionNumber.new(6, 4, 2)).should be_true
    Qt::VersionNumber.common_prefix(v1, v2).to_string.should eq("6")
    Qt::VersionNumber.from_string("1.2.3-beta").to_string.should eq("1.2.3")
    Qt::VersionNumber.new.null?.should be_true
    Qt::VersionNumber.new(1, 0).normalized.segment_count.should eq(1)
    Qt::LibraryInfo.version.major_version.should eq(6)
  end
end

describe Qt::CryptographicHash do
  it "hashes data" do
    sha = Qt::CryptographicHash.hash("abc".to_slice, Qt::CryptographicHash::Algorithm::Sha256)
    sha.hexstring.should eq("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    Qt::CryptographicHash.hash_length(Qt::CryptographicHash::Algorithm::Md5).should eq(16)

    hash = Qt::CryptographicHash.new(Qt::CryptographicHash::Algorithm::Md5)
    hash.add_data("hello ".to_slice)
    hash.add_data("world".to_slice)
    hash.result.hexstring.should eq("5eb63bbbe01eeed093cb22bb8f5acdc3")
    hash.reset
    hash.result.hexstring.should eq("d41d8cd98f00b204e9800998ecf8427e")
  end
end

describe Qt::RandomGenerator do
  it "generates numbers" do
    generator = Qt::RandomGenerator.new(42_u32)
    first = generator.generate
    Qt::RandomGenerator.new(42_u32).generate.should eq(first)
    value = generator.bounded(10)
    (0...10).should contain(value)
    generator.bounded(5, 8).should be >= 5
    generator.generate_double.should be < 1.0
    Qt::RandomGenerator.global.not_nil!.bounded(1_u32).should eq(0)
    Qt::RandomGenerator64.global.not_nil!.generate.should be_a(UInt64)
  end
end

describe "timers" do
  it "measure elapsed time and deadlines" do
    timer = Qt::ElapsedTimer.new
    timer.valid?.should be_false
    timer.start
    timer.valid?.should be_true
    sleep 5.milliseconds
    timer.elapsed.should be >= 4
    timer.nsecs_elapsed.should be >= 4_000_000
    timer.has_expired(100_000).should be_false
    timer.restart.should be >= 4
    timer.invalidate
    timer.valid?.should be_false

    deadline = Qt::DeadlineTimer.new(1_000_i64)
    deadline.forever?.should be_false
    deadline.has_expired?.should be_false
    deadline.remaining_time.should be <= 1_000
    Qt::DeadlineTimer.new(Qt::DeadlineTimer::ForeverConstant::Forever).forever?.should be_true
    Qt::DeadlineTimer.new(0_i64).has_expired?.should be_true
    Qt::DeadlineTimer.current.has_expired?.should be_true
  end
end

describe Qt::CommandLineParser do
  it "parses arguments" do
    parser = Qt::CommandLineParser.new
    parser.application_description = "spec"
    verbose = Qt::CommandLineOption.new(["v", "verbose"], "Chatty output")
    output = Qt::CommandLineOption.new("output", "Output file", "file", "out.txt")
    parser.add_option(verbose).should be_true
    parser.add_option(output).should be_true
    parser.add_positional_argument("source", "Source file")
    parser.add_help_option

    parser.parse(["spec", "--verbose", "--output", "a.txt", "input.txt"]).should be_true
    parser.is_set(verbose).should be_true
    parser.is_set("v").should be_true
    parser.value(output).should eq("a.txt")
    parser.value("output").should eq("a.txt")
    parser.positional_arguments.to_a.should eq(["input.txt"])
    parser.option_names.to_a.should eq(["verbose", "output"])
    parser.help_text.should contain("--output")

    parser.parse(["spec"]).should be_true
    parser.is_set(verbose).should be_false
    parser.value(output).should eq("out.txt")

    parser.parse(["spec", "--bogus"]).should be_false
    parser.error_text.should contain("bogus")
    parser.unknown_option_names.to_a.should eq(["bogus"])

    option = Qt::CommandLineOption.new("x")
    option.names.to_a.should eq(["x"])
    option.flags = Qt::CommandLineOption::Flags::HiddenFromHelp
    option.flags.should eq(Qt::CommandLineOption::Flags::HiddenFromHelp)
  end
end

describe Qt::MimeDatabase do
  it "looks up mime types" do
    database = Qt::MimeDatabase.new
    png = database.mime_type_for_file("x.png", Qt::MimeDatabase::MatchMode::MatchExtension)
    png.valid?.should be_true
    png.name.should eq("image/png")
    png.preferred_suffix.should eq("png")
    png.suffixes.to_a.should contain("png")
    png.inherits("application/octet-stream").should be_true
    png.comment.should_not be_empty
    database.mime_type_for_name("text/plain").name.should eq("text/plain")
    database.mime_type_for_data("<html><body></body></html>".to_slice).name.should eq("text/html")
    database.mime_types_for_file_name("x.png").map(&.name).should contain("image/png")
    database.suffix_for_file_name("archive.tar.gz").should_not be_empty # "tar.gz" or "gz" by database
    database.mime_type_for_name("no/such").valid?.should be_false
    (png != database.mime_type_for_name("image/png")).should be_false
  end
end

describe Qt::Collator do
  it "compares strings" do
    collator = Qt::Collator.new(Qt::Locale.new("en_US"))
    collator.compare("a", "b").should be < 0
    collator.compare("b", "a").should be > 0
    collator.compare("same", "same").should eq(0)
    collator.call("a", "b").should be_true
    collator.case_sensitivity = Qt::CaseSensitivity::CaseInsensitive
    collator.compare("ABC", "abc").should eq(0)
    collator.numeric_mode = true
    collator.numeric_mode.should be_true
    collator.compare("file2", "file10").should be < 0
    key = collator.sort_key("file2")
    (key < collator.sort_key("file10")).should be_true
    key.compare(collator.sort_key("file2")).should eq(0)
  end
end

describe "system information" do
  it "describes the system" do
    Qt::SysInfo.build_cpu_architecture.should_not be_empty
    Qt::SysInfo.kernel_type.should_not be_empty
    Qt::SysInfo.pretty_product_name.should_not be_empty
    Qt::SysInfo.machine_host_name.should_not be_empty
    version = Qt::OperatingSystemVersion.current
    Qt::OperatingSystemVersion.current_type.should eq(version.type)
    {% if flag?(:darwin) %}
      version.major_version.should be > 0
      version.type.should_not eq(Qt::OperatingSystemVersion::OSType::Unknown)
      version.name.should_not be_empty
    {% else %}
      version.type.should eq(Qt::OperatingSystemVersion::OSType::Unknown) # Qt knows no version of Linux
    {% end %}
    {% if Qt::QT_VERSION >= 0x060500 %}
      Qt::OperatingSystemVersion.mac_os_sonoma.major_version.should eq(14)
    {% end %}
    Qt::LibraryInfo.path(Qt::LibraryInfo::LibraryPath::PrefixPath).should_not be_empty
  end
end

describe Qt::TimeZone do
  it "describes time zones" do
    utc = Qt::TimeZone.utc
    utc.valid?.should be_true
    String.new(utc.id).should eq("UTC")
    Qt::TimeZone.system_time_zone.valid?.should be_true
    Qt::TimeZone.is_time_zone_id_available("Europe/Zagreb".to_slice).should be_true
    zone = Qt::TimeZone.new("Europe/Zagreb".to_slice)
    zone.valid?.should be_true
    zone.has_daylight_time?.should be_true
    winter = Qt::DateTime.new(Qt::Date.new(2024, 1, 15), Qt::Time.new(12, 0), utc)
    zone.offset_from_utc(winter).should eq(3600)
    zone.abbreviation(winter).should_not be_empty # "CET" or "GMT+1" by backend
    summer = Qt::DateTime.new(Qt::Date.new(2024, 7, 15), Qt::Time.new(12, 0), utc)
    zone.offset_from_utc(summer).should eq(7200)
    zone.is_daylight_time(summer).should be_true
    data = zone.offset_data(summer)
    data.daylight_time_offset.should eq(3600)
    zone.transitions(winter, summer).size.should eq(1)
    {% if Qt::QT_VERSION >= 0x060500 %}
      Qt::TimeZone.from_seconds_ahead_of_utc(3600).fixed_seconds_ahead_of_utc.should eq(3600)
      Qt::TimeZone.from_duration_ahead_of_utc(-2.hours).fixed_seconds_ahead_of_utc.should eq(-7200)
    {% end %}
    Qt::TimeZone.available_time_zone_ids.map { |id| String.new(id) }.should contain("Europe/Zagreb")
    Qt::TimeZone.new("Nowhere/Land".to_slice).valid?.should be_false
  end
end

describe Qt::Translator do
  it "loads nothing by default" do
    translator = Qt::Translator.new
    translator.empty?.should be_true
    translator.load("no-such-file.qm").should be_false
    translator.translate("Context".to_unsafe, "Hello".to_unsafe).should eq("")
    # Qt 6.10 installs an empty translator; older Qt refuses it.
    Qt::CoreApplication.install_translator(translator).should eq(Qt::QT_VERSION >= 0x060a00)
    Qt::CoreApplication.remove_translator(translator).should be_true
  end
end
