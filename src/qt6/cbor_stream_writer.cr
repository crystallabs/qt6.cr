module Qt
  class CborStreamWriter
    # Qt 6.10 added the `append(QUtf8StringView)` overload the generated
    # `append(String)` is; older Qt takes the UTF-8 bytes and their count.
    {% if QT_VERSION < 0x060a00 %}
      def append(str : String) : Void
        append_text_string(str.to_unsafe, str.bytesize.to_i64)
      end
    {% end %}
  end
end
