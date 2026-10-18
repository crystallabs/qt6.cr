module Qt
  # `QAbstractListModel` overrides `parent`, `columnCount` and `hasChildren`
  # privately, so bindgen leaves them out of `AbstractListModelImpl`, which
  # `AbstractItemModel` declares abstract.  These do what Qt's do.  See also
  # `AbstractProxyModelImpl` for the default-argument overloads.
  class AbstractListModelImpl
    def parent(child : ModelIndex) : ModelIndex
      ModelIndex.new
    end

    def column_count(parent : ModelIndex) : Int32
      parent.valid? ? 0 : 1
    end

    def has_children(parent : ModelIndex) : Bool
      parent.valid? ? false : row_count(parent) > 0
    end

    def row_count : Int32
      row_count(ModelIndex.new)
    end

    def column_count : Int32
      column_count(ModelIndex.new)
    end
  end
end
