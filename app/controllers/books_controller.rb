class BooksController < ApplicationController
  include Paginated

  def index
    books = paginate(Book.kept.strict_loading.includes(current_borrowing: :reader).order(:serial_number))

    render json: BookBlueprint.render_as_hash(books)
  end

  def show
    render_detailed_book
  end

  def create
    book = Book.create!(book_params)

    render json: BookBlueprint.render_as_hash(book), status: :created
  end

  def destroy
    Book.kept.find(params[:id]).discard!

    head :no_content
  end

  def borrow_book
    Borrowing.borrow!(book: Book.kept.find(params[:id]), reader: reader_from_card_number)

    render_detailed_book
  end

  def return_book
    Borrowing.return!(book: Book.kept.find(params[:id]), reader: reader_from_card_number)

    render_detailed_book
  end

  private

  def render_detailed_book
    book = Book.kept.strict_loading.includes(current_borrowing: :reader, borrowings: :reader).find(params[:id])

    render json: BookBlueprint.render_as_hash(book, view: :detailed)
  end

  def reader_from_card_number
    Reader.kept.find_by!(card_number: params.expect(:reader_card_number))
  end

  def book_params
    params.expect(book: %i[serial_number title author])
  end
end
