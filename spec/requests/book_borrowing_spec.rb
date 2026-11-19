require "rails_helper"

RSpec.describe "Book borrowing" do
  let(:json) { response.parsed_body }
  let(:book) { create(:book) }
  let!(:reader) { create(:reader, card_number: "000123") }

  describe "POST /books/:id/borrow" do
    it "lends the book to the reader for 30 days and returns the book" do
      travel_to Time.zone.local(2026, 5, 20, 9, 15, 30) do
        post borrow_book_path(book), params: { reader_card_number: "000123" }, as: :json

        borrowing_json = {
          "id" => Borrowing.sole.id,
          "borrowed_at" => Time.zone.local(2026, 5, 20, 9, 15, 30).iso8601,
          "due_on" => "2026-06-19",
          "returned_at" => nil,
          "reader" => reader_json(reader)
        }
        expect(response).to have_http_status(:ok)
        expect(json).to eq(
          "id" => book.id, "serial_number" => book.serial_number, "title" => book.title, "author" => book.author,
          "status" => "borrowed", "current_borrowing" => borrowing_json, "borrowings" => [ borrowing_json ]
        )
      end
    end

    it "shows the book as borrowed afterwards" do
      post borrow_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      get books_path

      expect(json).to eq([ book_json(book, status: "borrowed", current_borrowing: Borrowing.sole) ])
    end

    it "returns 409 when the book is already borrowed" do
      Borrowing.borrow!(book:, reader: create(:reader))

      post borrow_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq(error_json("conflict", "Book is already borrowed"))
    end

    it "returns 404 for an unknown reader card number" do
      post borrow_book_path(book), params: { reader_card_number: "999999" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Reader not found"))
    end

    it "returns 404 for a deleted reader" do
      reader.discard!

      post borrow_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Reader not found"))
    end

    it "returns 404 for a deleted book" do
      book.discard!

      post borrow_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Book not found"))
    end

    it "returns 400 without reader_card_number" do
      post borrow_book_path(book), params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "param is missing or the value is empty or invalid: reader_card_number"))
      expect(Borrowing.count).to eq(0)
    end
  end

  describe "POST /books/:id/return" do
    it "ends the borrowing and returns the book" do
      borrowing = Borrowing.borrow!(book:, reader:, at: Time.zone.local(2026, 5, 1, 10, 0))

      travel_to Time.zone.local(2026, 5, 20, 16, 45, 10) do
        post return_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json).to eq(
          "id" => book.id, "serial_number" => book.serial_number, "title" => book.title, "author" => book.author,
          "status" => "available", "current_borrowing" => nil,
          "borrowings" => [ {
            "id" => borrowing.id,
            "borrowed_at" => Time.zone.local(2026, 5, 1, 10, 0).iso8601,
            "due_on" => "2026-05-31",
            "returned_at" => Time.zone.local(2026, 5, 20, 16, 45, 10).iso8601,
            "reader" => reader_json(reader)
          } ]
        )
      end
    end

    it "returns 409 when the book is not borrowed" do
      post return_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq(error_json("conflict", "Book is not borrowed"))
    end

    it "returns 409 when another reader borrowed the book" do
      borrowing = Borrowing.borrow!(book:, reader: create(:reader))

      post return_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq(error_json("conflict", "Book borrowed by another reader"))
      expect(borrowing.reload).to be_active
    end

    it "returns 404 for an unknown reader card number" do
      post return_book_path(book), params: { reader_card_number: "999999" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Reader not found"))
    end

    it "returns 404 for a deleted book" do
      book.discard!

      post return_book_path(book), params: { reader_card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Book not found"))
    end

    it "returns 400 without reader_card_number" do
      post return_book_path(book), params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "param is missing or the value is empty or invalid: reader_card_number"))
    end
  end
end
