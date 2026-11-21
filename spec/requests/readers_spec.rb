require "rails_helper"

RSpec.describe "Readers" do
  let(:json) { response.parsed_body }

  describe "GET /readers" do
    context "with kept and deleted readers" do
      before do
        create(:reader, card_number: "000003", name: "Carol", email: nil)
        create(:reader, card_number: "000001", name: "Alice", email: "alice@example.com")
        create(:reader, card_number: "000002").discard
        get readers_path
      end

      it { expect(response).to have_http_status(:ok) }

      it "lists kept readers ordered by card number" do
        expect(json).to eq([
          { "card_number" => "000001", "name" => "Alice", "email" => "alice@example.com" },
          { "card_number" => "000003", "name" => "Carol", "email" => nil }
        ])
      end
    end

    it_behaves_like "a paginated list", factory: :reader, order_by: "card_number" do
      let(:path) { readers_path }
    end
  end

  describe "POST /readers" do
    def create_reader(reader_params)
      post readers_path, params: { reader: reader_params }, as: :json
    end

    context "with valid attributes" do
      before { create_reader(card_number: "123456", name: "Ada", email: " Ada@Example.com ") }

      it { expect(response).to have_http_status(:created) }

      it "returns the reader with a normalized email" do
        expect(json).to eq("card_number" => "123456", "name" => "Ada", "email" => "ada@example.com")
      end
    end

    context "without an email" do
      before { create_reader(card_number: "123456", name: "Ada") }

      it { expect(response).to have_http_status(:created) }

      it "returns the reader without an email" do
        expect(json).to eq("card_number" => "123456", "name" => "Ada", "email" => nil)
      end
    end

    context "with invalid attributes" do
      before do
        create(:reader, email: "ada@example.com")
        create_reader(card_number: "123", name: "Ada", email: "ada@example.com")
      end

      it_behaves_like "an error response", :unprocessable_content,
                      "Card number must be a six-digit number and Email has already been taken",
                      { "card_number" => [ "must be a six-digit number" ], "email" => [ "has already been taken" ] }
    end

    context "without reader attributes" do
      before { post readers_path, params: {}, as: :json }

      it_behaves_like "an error response", :bad_request, "param is missing or the value is empty or invalid: reader"
    end

    context "with a malformed JSON body" do
      before { post readers_path, params: "{not json", headers: { "CONTENT_TYPE" => "application/json" } }

      it_behaves_like "an error response", :bad_request, "Error occurred while parsing request parameters"
    end

    context "with unknown attributes" do
      before { create_reader(card_number: "123456", name: "Ada", nickname: "Countess") }

      it { expect(response).to have_http_status(:created) }

      it "ignores them" do
        expect(json).to eq("card_number" => "123456", "name" => "Ada", "email" => nil)
      end
    end

    context "with attributes outside the permitted list" do
      before { create_reader(card_number: "123456", name: "Ada", discarded_at: Time.current) }

      it { expect(response).to have_http_status(:created) }

      it "ignores them" do
        expect(Reader.sole).to be_kept
      end
    end

    context "when reader is not an object" do
      before { create_reader("Ada") }

      it_behaves_like "an error response", :bad_request, "param is missing or the value is empty or invalid: reader"
    end
  end

  describe "DELETE /readers/:card_number" do
    let(:reader) { create(:reader) }

    context "when the reader has no borrowed books" do
      before { delete reader_path(reader) }

      it { expect(response).to have_http_status(:no_content) }

      it { expect(response.body).to be_empty }

      it "soft-deletes the reader" do
        expect(reader.reload).to be_discarded
      end
    end

    context "when the reader is already deleted" do
      before do
        reader.discard
        delete reader_path(reader)
      end

      it_behaves_like "an error response", :not_found, "Reader not found"
    end

    context "when the reader has a borrowed book" do
      before do
        Borrowing.borrow!(book: create(:book), reader:)
        delete reader_path(reader)
      end

      it_behaves_like "an error response", :conflict, "Reader has borrowed books that are not returned"

      it "keeps the reader" do
        expect(reader.reload).to be_kept
      end
    end
  end
end
