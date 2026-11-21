require "rails_helper"

RSpec.describe "Books" do
  let(:json) { response.parsed_body }
  let(:book) { create(:book) }

  describe "GET /books" do
    context "with available, borrowed and deleted books" do
      let!(:available) { create(:book, serial_number: "000002", title: "Emma", author: "Jane Austen") }
      let!(:borrowed) { create(:book, serial_number: "000001") }

      before do
        Borrowing.borrow!(book: borrowed, reader: create(:reader))
        create(:book, serial_number: "000003").discard
        get books_path
      end

      it { expect(response).to have_http_status(:ok) }

      it "lists kept books with their status, ordered by serial number" do
        expect(json).to eq(page_json([
          book_json(borrowed, status: "borrowed"),
          book_json(available, status: "available")
        ]))
      end
    end

    it_behaves_like "a paginated list", factory: :book, order_by: "serial_number" do
      let(:path) { books_path }
    end
  end

  describe "GET /books/:serial_number" do
    context "with a borrowing history" do
      let!(:former) { create(:borrowing, :returned, book:, borrowed_at: 2.months.ago) }
      let!(:current) { Borrowing.borrow!(book:, reader: create(:reader)).reload }

      before do
        former.reader.discard!
        get book_path(book)
      end

      it { expect(response).to have_http_status(:ok) }

      it "returns the book with its history, newest first, including deleted readers" do
        expect(json).to eq(
          book_json(book, status: "borrowed", recent_borrowings: [ current, former.reload ])
        )
      end
    end

    context "with more than 3 borrowings" do
      let!(:recent) do
        [ 1.week, 2.weeks, 3.weeks ].map { |age| create(:borrowing, :returned, book:, borrowed_at: age.ago) }
      end

      before do
        create(:borrowing, :returned, book:, borrowed_at: 1.month.ago)
        get book_path(book)
      end

      it "returns the 3 newest borrowings and the total count" do
        expect(json).to eq(book_json(book, status: "available", recent_borrowings: recent, borrowings_count: 4))
      end
    end

    context "when the book was never borrowed" do
      before { get book_path(book) }

      it "returns an empty history" do
        expect(json).to eq(book_json(book, status: "available", recent_borrowings: []))
      end
    end

    context "when the book is deleted" do
      before do
        book.discard!
        get book_path(book)
      end

      it_behaves_like "an error response", :not_found, "Book not found"
    end
  end

  describe "POST /books" do
    let(:book_params) { { serial_number: "012345", title: "Persuasion", author: "Jane Austen" } }

    context "with valid attributes" do
      before { post books_path, params: { book: book_params }, as: :json }

      it { expect(response).to have_http_status(:created) }

      it "returns the created book" do
        expect(json).to eq(book_json(Book.sole, status: "available"))
      end
    end

    context "with a serial number used by a kept book" do
      before do
        create(:book, serial_number: "012345")
        post books_path, params: { book: book_params }, as: :json
      end

      it_behaves_like "an error response", :unprocessable_content, "Serial number has already been taken",
                      { "serial_number" => [ "has already been taken" ] }
    end

    context "with a serial number used by a deleted book" do
      before do
        create(:book, serial_number: "012345").discard!
        post books_path, params: { book: book_params }, as: :json
      end

      it_behaves_like "an error response", :unprocessable_content, "Serial number has already been taken",
                      { "serial_number" => [ "has already been taken" ] }
    end

    context "without book attributes" do
      before { post books_path, params: {}, as: :json }

      it_behaves_like "an error response", :bad_request, "param is missing or the value is empty or invalid: book"
    end
  end

  describe "DELETE /books/:serial_number" do
    context "when the book is available" do
      before { delete book_path(book) }

      it { expect(response).to have_http_status(:no_content) }

      it { expect(response.body).to be_empty }

      it "soft-deletes the book" do
        expect(book.reload).to be_discarded
      end
    end

    context "when the book is already deleted" do
      before do
        book.discard!
        delete book_path(book)
      end

      it_behaves_like "an error response", :not_found, "Book not found"
    end

    context "when the book is borrowed" do
      before do
        Borrowing.borrow!(book:, reader: create(:reader))
        delete book_path(book)
      end

      it_behaves_like "an error response", :conflict, "Book is currently borrowed"

      it "keeps the book" do
        expect(book.reload).to be_kept
      end
    end
  end
end
