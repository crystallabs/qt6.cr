module Qt
  # bindgen 0.11.1 gives the `Impl` class of an abstract class only the pure
  # virtual methods it copies from its base, without the overloads their
  # default arguments add.  `AbstractItemModel` declares those abstract, so
  # `AbstractProxyModelImpl` has to implement them here.
  class AbstractProxyModelImpl
    def index(row : Int32, column : Int32) : ModelIndex
      index(row, column, ModelIndex.new)
    end

    def row_count : Int32
      row_count(ModelIndex.new)
    end

    def column_count : Int32
      column_count(ModelIndex.new)
    end
  end
end
