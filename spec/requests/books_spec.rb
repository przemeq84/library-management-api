require "rails_helper"

RSpec.describe "Books" do
  let(:json) { response.parsed_body }

  def reader_json(reader)
    { "id" => reader.id, "card_number" => reader.card_number, "name" => reader.name, "email" => reader.email }
  end

  def borrowing_json(borrowing)
    {
      "id" => borrowing.id,
      "borrowed_at" => borrowing.borrowed_at.iso8601,
      "due_on" => borrowing.due_on.iso8601,
      "returned_at" => borrowing.returned_at&.iso8601,
      "reader" => reader_json(borrowing.reader)
    }
  end

  describe "GET /books" do
    it "lists kept books with their status and current borrowing, ordered by serial number" do
      available = create(:book, serial_number: "000002", title: "Emma", author: "Jane Austen")
      borrowed = create(:book, serial_number: "000001")
      create(:book, serial_number: "000003").discard
      borrowing = Borrowing.borrow!(book: borrowed, reader: create(:reader))

      get books_path

      expect(response).to have_http_status(:ok)
      expect(json.pluck("serial_number")).to eq(%w[000001 000002])
      expect(json.first).to include("status" => "borrowed", "current_borrowing" => borrowing_json(borrowing.reload))
      expect(json.second).to eq(
        "id" => available.id, "serial_number" => "000002", "title" => "Emma", "author" => "Jane Austen",
        "status" => "available", "current_borrowing" => nil
      )
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
      Borrowing.borrow!(book:, reader: current_reader)
      current = book.current_borrowing

      former_reader.discard!

      get book_path(book)

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        "id" => book.id, "serial_number" => book.serial_number, "title" => book.title, "author" => book.author,
        "status" => "borrowed", "current_borrowing" => borrowing_json(current)
      )
      expect(json["borrowings"]).to eq([ borrowing_json(current), borrowing_json(first.reload) ])
    end

    it "returns an empty history for a book that was never borrowed" do
      book = create(:book)

      get book_path(book)

      expect(json).to include("status" => "available", "current_borrowing" => nil, "borrowings" => [])
    end

    it "returns 404 for a deleted book" do
      book = create(:book)
      book.discard!

      get book_path(book)

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to include("status" => "not_found", "message" => "Book not found")
    end
  end

  describe "POST /books" do
    it "creates a book" do
      post books_path, params: { book: { serial_number: "012345", title: "Persuasion", author: "Jane Austen" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include(
        "serial_number" => "012345", "title" => "Persuasion", "author" => "Jane Austen",
        "status" => "available", "current_borrowing" => nil
      )
      expect(Book.find(json["id"]).title).to eq("Persuasion")
    end

    it "returns 422 for a serial number used by a kept book" do
      create(:book, serial_number: "012345")

      post books_path, params: { book: { serial_number: "012345", title: "Persuasion", author: "Jane Austen" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details")).to eq("serial_number" => [ "has already been taken" ])
    end

    it "returns 400 without book attributes" do
      post books_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /books/:id" do
    it "soft-deletes the book" do
      book = create(:book)

      delete book_path(book)

      expect(response).to have_http_status(:no_content)
      expect(book.reload).to be_discarded
    end

    it "returns 404 for an already deleted book" do
      book = create(:book)
      book.discard!

      delete book_path(book)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 409 while the book is borrowed" do
      book = create(:book)
      Borrowing.borrow!(book:, reader: create(:reader))

      delete book_path(book)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to include("status" => "conflict", "message" => "Book is currently borrowed")
      expect(book.reload).to be_kept
    end
  end
end
