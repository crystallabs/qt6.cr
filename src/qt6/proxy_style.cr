module Qt
  class ProxyStyle
    # bindgen 0.11.1 passes a nilable argument like `widget : Widget? = nil` to
    # the C function as is, which Crystal accepts for `nil` or an object, but
    # not for their union, which the jump table of a Crystal override passes
    # on: `superclass.pixel_metric(metric, option, widget)` from an override
    # didn't compile.  These pass the pointers instead.
    class Superclass
      private def pointer(object) : Void*
        object ? object.to_unsafe.as(Void*) : Pointer(Void).null
      end

      def draw_primitive(pe : Style::PrimitiveElement, opt : StyleOption, p : Painter, w : Widget? = nil) : Void
        Binding.bg_QProxyStyle_drawPrimitive_SUPER_QStyle__PrimitiveElement_const_QStyleOption_X_QPainter_X_const_QWidget_X(@myself, pe, opt, p, pointer(w))
      end

      def draw_control(element : Style::ControlElement, opt : StyleOption, p : Painter, w : Widget? = nil) : Void
        Binding.bg_QProxyStyle_drawControl_SUPER_QStyle__ControlElement_const_QStyleOption_X_QPainter_X_const_QWidget_X(@myself, element, opt, p, pointer(w))
      end

      def draw_complex_control(cc : Style::ComplexControl, opt : StyleOptionComplex, p : Painter, widget : Widget? = nil) : Void
        Binding.bg_QProxyStyle_drawComplexControl_SUPER_QStyle__ComplexControl_const_QStyleOptionComplex_X_QPainter_X_const_QWidget_X(@myself, cc, opt, p, pointer(widget))
      end

      def size_from_contents(ct : Style::ContentsType, opt : StyleOption, contents_size : Size, w : Widget? = nil) : Size
        Size.new(unwrap: Binding.bg_QProxyStyle_sizeFromContents_SUPER_QStyle__ContentsType_const_QStyleOption_X_const_QSize_R_const_QWidget_X(@myself, ct, opt, contents_size, pointer(w)))
      end

      def sub_element_rect(sub_element : Style::SubElement, option : StyleOption, widget : Widget? = nil) : Rect
        Rect.new(unwrap: Binding.bg_QProxyStyle_subElementRect_SUPER_QStyle__SubElement_const_QStyleOption_X_const_QWidget_X(@myself, sub_element, option, pointer(widget)))
      end

      def sub_control_rect(cc : Style::ComplexControl, opt : StyleOptionComplex, sc : Style::SubControl, widget : Widget? = nil) : Rect
        Rect.new(unwrap: Binding.bg_QProxyStyle_subControlRect_SUPER_QStyle__ComplexControl_const_QStyleOptionComplex_X_QStyle__SubControl_const_QWidget_X(@myself, cc, opt, sc, pointer(widget)))
      end

      def hit_test_complex_control(cc : Style::ComplexControl, opt : StyleOptionComplex, pt : Point, widget : Widget? = nil) : Style::SubControl
        Binding.bg_QProxyStyle_hitTestComplexControl_SUPER_QStyle__ComplexControl_const_QStyleOptionComplex_X_const_QPoint_R_const_QWidget_X(@myself, cc, opt, pt, pointer(widget))
      end

      def style_hint(stylehint : Style::StyleHint, opt : StyleOption? = nil, widget : Widget? = nil, return_data : StyleHintReturn? = nil) : Int32
        Binding.bg_QProxyStyle_styleHint_SUPER_QStyle__StyleHint_const_QStyleOption_X_const_QWidget_X_QStyleHintReturn_X(@myself, stylehint, pointer(opt), pointer(widget), pointer(return_data))
      end

      def pixel_metric(metric : Style::PixelMetric, option : StyleOption? = nil, widget : Widget? = nil) : Int32
        Binding.bg_QProxyStyle_pixelMetric_SUPER_QStyle__PixelMetric_const_QStyleOption_X_const_QWidget_X(@myself, metric, pointer(option), pointer(widget))
      end

      def layout_spacing(control1 : SizePolicy::ControlType, control2 : SizePolicy::ControlType, orientation : Orientation, option : StyleOption? = nil, widget : Widget? = nil) : Int32
        Binding.bg_QProxyStyle_layoutSpacing_SUPER_QSizePolicy__ControlType_QSizePolicy__ControlType_Qt__Orientation_const_QStyleOption_X_const_QWidget_X(@myself, control1, control2, orientation, pointer(option), pointer(widget))
      end

      def standard_icon(standard_icon : Style::StandardPixmap, option : StyleOption? = nil, widget : Widget? = nil) : Icon
        Icon.new(unwrap: Binding.bg_QProxyStyle_standardIcon_SUPER_QStyle__StandardPixmap_const_QStyleOption_X_const_QWidget_X(@myself, standard_icon, pointer(option), pointer(widget)))
      end

      def standard_pixmap(standard_pixmap : Style::StandardPixmap, opt : StyleOption? = nil, widget : Widget? = nil) : Pixmap
        Pixmap.new(unwrap: Binding.bg_QProxyStyle_standardPixmap_SUPER_QStyle__StandardPixmap_const_QStyleOption_X_const_QWidget_X(@myself, standard_pixmap, pointer(opt), pointer(widget)))
      end
    end
  end
end
