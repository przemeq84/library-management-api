require "rails_helper"

RSpec.describe "Books" do
  let(:json) { response.parsed_body }

  describe "GET /books" do
    it "lists kept books with their status and current borrowing, ordered by serial number" do
      available = create(:book, serial_number: "000002", title: "Emma", author: "Jane Austen")
      borrowed = create(:book, serial_number: "000001")
      create(:book, serial_number: "000003").discard
      borrowing = Borrowing.borrow!(book: borrowed, reader: create(:reader))

      get books_path

      expect(response).to have_http_status(:ok)
      expect(json).to eq([
        book_json(borrowed, status: "borrowed", current_borrowing: borrowing.reload),
        {
          "id" => available.id, "serial_number" => "000002", "title" => "Emma", "author" => "Jane Austen",
          "status" => "available", "current_borrowing" => nil
        }
      ])
    end

    it_behaves_like "a paginated list", factory: :book, order_by: "serial_number" do
      let(:path) { books_path }
    end
  end

  describe "GET /books/:id" do
    it "returns the book with its full borrowing history, newest first" do
      book = create(:book)
      former_reader = create(:reader)
      current_reader = create(:reader)
      first = create(:borrowing, :returned, book:, reader: former_reader, borrowed_at: 2.months.ago)
      current = Borrowing.borrow!(book:, reader: current_reader).reload

      former_reader.discard!

      get book_path(book)

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        book_json(book, status: "borrowed", current_borrowing: current, borrowings: [ current, first.reload ])
      )
    end

    it "returns an empty history for a book that was never borrowed" do
      book = create(:book)

      get book_path(book)

      expect(json).to eq(book_json(book, status: "available", borrowings: []))
    end

    it "returns 404 for a deleted book" do
      book = create(:book)
      book.discard!

      get book_path(book)

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Book not found"))
    end
  end

  describe "POST /books" do
    it "creates a book" do
      post books_path, params: { book: { serial_number: "012345", title: "Persuasion", author: "Jane Austen" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq(
        "id" => Book.sole.id, "serial_number" => "012345", "title" => "Persuasion", "author" => "Jane Austen",
        "status" => "available", "current_borrowing" => nil
      )
    end

    it "returns 422 for a serial number used by a kept book" do
      create(:book, serial_number: "012345")

      post books_path, params: { book: { serial_number: "012345", title: "Persuasion", author: "Jane Austen" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(error_json(
        "unprocessable_content", "Serial number has already been taken", "serial_number" => [ "has already been taken" ]
      ))
    end

    it "returns 400 without book attributes" do
      post books_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "param is missing or the value is empty or invalid: book"))
    end
  end

  describe "DELETE /books/:id" do
    it "soft-deletes the book" do
      book = create(:book)

      delete book_path(book)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(book.reload).to be_discarded
    end

    it "returns 404 for an already deleted book" do
      book = create(:book)
      book.discard!

      delete book_path(book)

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Book not found"))
    end

    it "returns 409 while the book is borrowed" do
      book = create(:book)
      Borrowing.borrow!(book:, reader: create(:reader))

      delete book_path(book)

      expect(response).to have_http_status(:conflict)
      expect(json).to eq(error_json("conflict", "Book is currently borrowed"))
      expect(book.reload).to be_kept
    end
  end
end
