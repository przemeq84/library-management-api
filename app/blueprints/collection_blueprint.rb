class CollectionBlueprint < Blueprinter::Base
  field :data do |page, options|
    options.fetch(:item_blueprint)
           .render_as_hash(page[:items], view: options.fetch(:item_view, :default))
  end

  field :meta do |page, _options|
    {
      page: page[:items].current_page,
      per_page: page[:items].per_page,
      total: page[:items].total_entries
    }
  end

  def self.render_page(items, blueprint:, view: :default, options: {})
    render_as_hash({ items: }, item_blueprint: blueprint, item_view: view, **options)
  end
end
