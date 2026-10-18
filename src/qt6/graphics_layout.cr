module Qt
  # bindgen 0.11.1 gives the `Impl` class of an abstract class only the pure
  # virtual methods it copies from its base, without the overloads their
  # default arguments add: `GraphicsLayoutItem` declares
  # `size_hint(which)` abstract, so `GraphicsLayoutImpl` implements it here,
  # like `AbstractProxyModelImpl` does.
  class GraphicsLayoutImpl
    protected def size_hint(which : SizeHint) : SizeF
      size_hint(which, SizeF.new)
    end
  end
end
