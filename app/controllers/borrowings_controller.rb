class BorrowingsController < ApplicationController
  include Paginated

  def index
    book = Book.find_by!(serial_number: params[:book_serial_number])
    borrowings = Borrowing.where(book:)
                          .preload(:reader)
                          .order(borrowed_at: :desc)
                          .strict_loading
    borrowings = paginate(borrowings)

    render json: CollectionBlueprint.render_page(borrowings, blueprint: BorrowingBlueprint)
  end
end
