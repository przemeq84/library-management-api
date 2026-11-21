require "rails_helper"

RSpec.describe "Borrowings" do
  let(:json) { response.parsed_body }
  let(:book) { create(:book) }

  describe "GET /borrowings?book_serial_number=" do
    def list_borrowings(params = {})
      get borrowings_path, params: { book_serial_number: book.serial_number, **params }
    end

    context "with a borrowing history" do
      let!(:former) { create(:borrowing, :returned, book:, borrowed_at: 2.months.ago) }
      let!(:current) { create(:borrowing, book:, borrowed_at: 1.day.ago) }
      let!(:oldest) { create(:borrowing, :returned, book:, borrowed_at: 3.months.ago) }

      before do
        create(:borrowing, :returned, borrowed_at: 1.week.ago)
        list_borrowings
      end

      it { expect(response).to have_http_status(:ok) }

      it "lists the book's borrowings, newest first" do
        expect(json).to eq(page_json([ current, former, oldest ].map { |borrowing| borrowing_json(borrowing) }))
      end
    end

    context "with page and per_page" do
      let!(:oldest) { create(:borrowing, :returned, book:, borrowed_at: 3.months.ago) }

      before do
        create(:borrowing, :returned, book:, borrowed_at: 2.months.ago)
        create(:borrowing, :returned, book:, borrowed_at: 1.month.ago)
        list_borrowings(page: 2, per_page: 2)
      end

      it "returns the requested page" do
        expect(json).to eq(page_json([ borrowing_json(oldest) ], page: 2, per_page: 2, total: 3))
      end
    end

    context "when the book was never borrowed" do
      before { list_borrowings }

      it "returns an empty list" do
        expect(json).to eq(page_json([]))
      end
    end

    context "when the book is deleted" do
      let!(:borrowing) { create(:borrowing, :returned, book:) }

      before do
        book.discard!
        list_borrowings
      end

      it "still lists its borrowings" do
        expect(json).to eq(page_json([ borrowing_json(borrowing) ]))
      end
    end

    context "with an unknown serial number" do
      before { list_borrowings(book_serial_number: "999999") }

      it_behaves_like "an error response", :not_found, "Book not found"
    end

    context "with an invalid page" do
      before { list_borrowings(page: "0") }

      it_behaves_like "an error response", :bad_request, "page must be a positive integer"
    end
  end
end
