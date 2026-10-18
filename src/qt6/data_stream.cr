module Qt
  # Qt streams `QString` and `QByteArray` through free `operator<<` and
  # `operator>>`, which bindgen doesn't wrap as methods, so these come from
  # `ext/xml_helper.hpp`.  The numbers are read through `#read`:
  #
  # ```
  # stream << 42 << "text"
  # stream.read(Int32)  # => 42
  # stream.read(String) # => "text"
  # ```
  class DataStream
    # Writes *string* as Qt does, in UTF-16 with its length.
    def <<(string : String) : DataStream
      Qt.qt6cr_data_stream_write_string(self, string)
      self
    end

    # Writes *value* as Qt does, as one byte: bindgen wraps the other
    # `operator<<` overloads of QDataStream, but not `operator<<(bool)`.
    def <<(value : Bool) : DataStream
      self << (value ? 1_i8 : 0_i8)
    end

    # Reads a string written by `#<<`.
    def read_string : String
      Qt.qt6cr_data_stream_read_string(self)
    end

    # Reads the bytes written by `#<<`.
    def read_bytes : Bytes
      Qt.qt6cr_data_stream_read_bytes(self)
    end

    {% for type in [Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64] %}
      # Reads a `{{type}}` written by `#<<`.
      def read(type : {{type}}.class) : {{type}}
        value = uninitialized {{type}}
        self >> pointerof(value)
        value
      end
    {% end %}

    # Reads a `String` written by `#<<`.
    def read(type : String.class) : String
      read_string
    end

    # Reads the `Bytes` written by `#<<`.
    def read(type : Bytes.class) : Bytes
      read_bytes
    end
  end
end
