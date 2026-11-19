class ReadersController < ApplicationController
  include Paginated

  def index
    readers = paginate(Reader.kept.order(:card_number))

    render json: ReaderBlueprint.render_as_hash(readers)
  end

  def create
    reader = Reader.create!(reader_params)

    render json: ReaderBlueprint.render_as_hash(reader), status: :created
  end

  def destroy
    Reader.kept.find(params[:id]).discard!

    head :no_content
  end

  private

  def reader_params
    params.expect(reader: %i[card_number name email])
  end
end
