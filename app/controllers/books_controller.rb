class BooksController < ApplicationController
  include Paginated

  before_action :set_book_from_serial_number, only: [ :destroy, :borrow_book, :return_book ]
  def index
    books = paginate(Book.kept.strict_loading.order(:serial_number))

    render json: CollectionBlueprint.render_page(books, blueprint: BookBlueprint)
  end

  def show
    render_detailed_book(include_discarded: true)
  end

  def create
    book = Book.create!(book_params)

    render json: BookBlueprint.render_as_hash(book), status: :created
  end

  def destroy
    @book.discard!

    head :no_content
  end

  def borrow_book
    Borrowing.borrow!(book: @book, reader: reader_from_card_number)

    render_detailed_book
  end

  def return_book
    Borrowing.return!(book: @book)

    render_detailed_book
  end

  private

  def render_detailed_book(include_discarded: false)
    books = include_discarded ? Book.all : Book.kept
    book = books.strict_loading
                .includes(current_borrowing: :reader, recent_borrowings_chronological: :reader)
                .find_by!(serial_number: params[:serial_number])

    borrowings_count = book.borrowings.count

    render json: BookBlueprint.render_as_hash(book, view: :detailed, borrowings_count:)
  end

  def reader_from_card_number
    Reader.kept.find_by!(card_number: params.expect(:reader_card_number))
  end

  def book_params
    params.expect(book: %i[serial_number title author])
  end

  def set_book_from_serial_number
    @book = Book.kept.find_by!(serial_number: params[:serial_number])
  end
end
