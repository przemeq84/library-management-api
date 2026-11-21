class ReadersController < ApplicationController
  include Paginated

  def index
    readers = paginate(Reader.kept.order(:card_number))

    render json: CollectionBlueprint.render_page(readers, blueprint: ReaderBlueprint)
  end

  def create
    reader = Reader.create!(reader_params)

    render json: ReaderBlueprint.render_as_hash(reader), status: :created
  end

  def destroy
    Reader.kept.find_by!(card_number: params[:card_number]).discard!

    head :no_content
  end

  private

  def reader_params
    params.expect(reader: %i[card_number name email])
  end
end
