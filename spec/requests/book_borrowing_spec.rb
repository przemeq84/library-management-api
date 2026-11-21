require "rails_helper"

RSpec.describe "Book borrowing" do
  let(:json) { response.parsed_body }
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }

  describe "POST /books/:serial_number/borrow" do
    def borrow(params = { reader_card_number: reader.card_number })
      post borrow_book_path(book), params:, as: :json
    end

    context "when the book is available" do
      let(:now) { Time.zone.local(2026, 5, 20, 9, 15, 30) }
      let(:expected_borrowing) do
        {
          "id" => Borrowing.sole.id,
          "status" => "active",
          "borrowed_at" => now.iso8601,
          "due_on" => "2026-06-19",
          "returned_at" => nil,
          "reader" => reader_json(reader)
        }
      end

      before do
        travel_to now
        borrow
      end

      it { expect(response).to have_http_status(:ok) }

      it "lends the book to the reader for 30 days and returns the book" do
        expect(json).to eq(
          "serial_number" => book.serial_number, "title" => book.title, "author" => book.author,
          "status" => "borrowed", "current_borrowing" => expected_borrowing,
          "recent_borrowings" => [ expected_borrowing ], "borrowings_count" => 1
        )
      end

      it "shows the book as borrowed afterwards" do
        get books_path

        expect(json).to eq(page_json([ book_json(book, status: "borrowed", current_borrowing: Borrowing.sole) ]))
      end
    end

    context "when the book is already borrowed" do
      before do
        Borrowing.borrow!(book:, reader: create(:reader))
        borrow
      end

      it_behaves_like "an error response", :conflict, "Book is already borrowed"
    end

    context "with an unknown reader card number" do
      before { borrow(reader_card_number: "999999") }

      it_behaves_like "an error response", :not_found, "Reader not found"
    end

    context "when the reader is deleted" do
      before do
        reader.discard!
        borrow
      end

      it_behaves_like "an error response", :not_found, "Reader not found"
    end

    context "when the book is deleted" do
      before do
        book.discard!
        borrow
      end

      it_behaves_like "an error response", :not_found, "Book not found"
    end

    context "without reader_card_number" do
      before { borrow({}) }

      it_behaves_like "an error response", :bad_request,
                      "param is missing or the value is empty or invalid: reader_card_number"

      it "records no borrowing" do
        expect(Borrowing.count).to eq(0)
      end
    end
  end

  describe "POST /books/:serial_number/return" do
    def return_book(params = { reader_card_number: reader.card_number })
      post return_book_path(book), params:, as: :json
    end

    context "when the reader has the book" do
      let(:borrowed_at) { Time.zone.local(2026, 5, 1, 10, 0) }
      let!(:borrowing) { Borrowing.borrow!(book:, reader:, at: borrowed_at) }

      before do
        travel_to Time.zone.local(2026, 5, 20, 16, 45, 10)
        return_book
      end

      it { expect(response).to have_http_status(:ok) }

      it "ends the borrowing and returns the book" do
        expect(json).to eq(
          "serial_number" => book.serial_number, "title" => book.title, "author" => book.author,
          "status" => "available", "current_borrowing" => nil, "borrowings_count" => 1,
          "recent_borrowings" => [ {
            "id" => borrowing.id,
            "status" => "returned",
            "borrowed_at" => borrowed_at.iso8601,
            "due_on" => "2026-05-31",
            "returned_at" => Time.current.iso8601,
            "reader" => reader_json(reader)
          } ]
        )
      end
    end

    context "when the book is not borrowed" do
      before { return_book }

      it_behaves_like "an error response", :conflict, "Book is not borrowed"
    end

    context "when another reader borrowed the book" do
      let!(:borrowing) { Borrowing.borrow!(book:, reader: create(:reader)) }

      before { return_book }

      it_behaves_like "an error response", :conflict, "Book borrowed by another reader"

      it "keeps the borrowing active" do
        expect(borrowing.reload).to be_active
      end
    end

    context "with an unknown reader card number" do
      before { return_book(reader_card_number: "999999") }

      it_behaves_like "an error response", :not_found, "Reader not found"
    end

    context "when the book is deleted" do
      before do
        book.discard!
        return_book
      end

      it_behaves_like "an error response", :not_found, "Book not found"
    end

    context "without reader_card_number" do
      before { return_book({}) }

      it_behaves_like "an error response", :bad_request,
                      "param is missing or the value is empty or invalid: reader_card_number"
    end
  end
end
