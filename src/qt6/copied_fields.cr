module Qt
  # bindgen gives a copied structure of `kind: Struct` no property methods for
  # its public fields, as they're in `#to_unsafe` (and `kind: Class` with
  # `pass_by: Value` generates a constructor that doesn't compile), so these
  # structures of plain fields get them here.

  # An element of a `PainterPath`, see `PainterPath#element_at`.
  struct PainterPathElement
    def x : Float64
      @unwrap.x
    end

    def y : Float64
      @unwrap.y
    end

    def type : PainterPath::ElementType
      @unwrap.type
    end
  end

  # The primary points of a `ColorSpace`, see `ColorSpacePrimaryPoints.from_primaries`.
  struct ColorSpacePrimaryPoints
    def white_point : PointF
      PointF.new(unwrap: @unwrap.white_point)
    end

    def red_point : PointF
      PointF.new(unwrap: @unwrap.red_point)
    end

    def green_point : PointF
      PointF.new(unwrap: @unwrap.green_point)
    end

    def blue_point : PointF
      PointF.new(unwrap: @unwrap.blue_point)
    end
  end

  # An axis of a `Quaternion`, see `Quaternion#to_axes`.
  struct QuaternionAxis
    def x : Float32
      @unwrap.x
    end

    def y : Float32
      @unwrap.y
    end

    def z : Float32
      @unwrap.z
    end
  end

  # The axes of a `Quaternion`, see `Quaternion#to_axes`.
  struct QuaternionAxes
    def x : QuaternionAxis
      QuaternionAxis.new(unwrap: @unwrap.x)
    end

    def y : QuaternionAxis
      QuaternionAxis.new(unwrap: @unwrap.y)
    end

    def z : QuaternionAxis
      QuaternionAxis.new(unwrap: @unwrap.z)
    end
  end

  # A range of pages, see `PageRanges#to_range_list`.
  struct PageRange
    def from : Int32
      @unwrap.from
    end

    def to : Int32
      @unwrap.to
    end
  end
end
