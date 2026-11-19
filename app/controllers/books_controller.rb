class BooksController < ApplicationController
  include Paginated

  def index
    books = paginate(Book.kept.strict_loading.includes(current_borrowing: :reader).order(:serial_number))

    render json: BookBlueprint.render_as_hash(books)
  end

  def show
    book = Book.kept.strict_loading.includes(current_borrowing: :reader, borrowings: :reader).find(params[:id])

    render json: BookBlueprint.render_as_hash(book, view: :detailed)
  end

  def create
    book = Book.create!(book_params)

    render json: BookBlueprint.render_as_hash(book), status: :created
  end

  def destroy
    Book.kept.find(params[:id]).discard!

    head :no_content
  end

  private

  def book_params
    params.expect(book: %i[serial_number title author])
  end
end
