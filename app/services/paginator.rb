# Paginación para colecciones en memoria (el volumen actual lo permite).
# Expone total, total_pages y el slice actual para que la vista pueda
# mostrar controles de navegación ("Mostrando x–y de z", anterior/siguiente").
class Paginator
  DEFAULT_PAGE_SIZE = 20

  attr_reader :collection, :page, :page_size

  def initialize(collection, page: nil, page_size: DEFAULT_PAGE_SIZE)
    @collection = collection
    @page_size = page_size
    @page = page.to_i.positive? ? page.to_i : 1
    @total_pages = [ 1, (collection.size.to_f / page_size).ceil ].max
    @page = @total_pages if @page > @total_pages
  end

  def total
    collection.size
  end

  def total_pages
    @total_pages
  end

  def offset
    (page - 1) * page_size
  end

  def items
    collection.slice(offset, page_size) || []
  end

  def first_item
    total.zero? ? 0 : offset + 1
  end

  def last_item
    [ offset + page_size, total ].min
  end

  def prev_page
    page > 1 ? page - 1 : nil
  end

  def next_page
    page < total_pages ? page + 1 : nil
  end
end
