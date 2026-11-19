require "rails_helper"

RSpec.describe "Readers" do
  let(:json) { response.parsed_body }

  describe "GET /readers" do
    it "lists kept readers ordered by card number" do
      carol = create(:reader, card_number: "000003", name: "Carol", email: nil)
      alice = create(:reader, card_number: "000001", name: "Alice", email: "alice@example.com")
      create(:reader, card_number: "000002").discard

      get readers_path

      expect(response).to have_http_status(:ok)
      expect(json).to eq([
        { "id" => alice.id, "card_number" => "000001", "name" => "Alice", "email" => "alice@example.com" },
        { "id" => carol.id, "card_number" => "000003", "name" => "Carol", "email" => nil }
      ])
    end

    it_behaves_like "a paginated list", factory: :reader, order_by: "card_number" do
      let(:path) { readers_path }
    end
  end

  describe "POST /readers" do
    it "creates a reader" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada", email: " Ada@Example.com " } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq("id" => Reader.sole.id, "card_number" => "123456", "name" => "Ada", "email" => "ada@example.com")
    end

    it "creates a reader without an email" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq("id" => Reader.sole.id, "card_number" => "123456", "name" => "Ada", "email" => nil)
    end

    it "returns 422 with validation details" do
      create(:reader, email: "ada@example.com")

      post readers_path, params: { reader: { card_number: "123", name: "Ada", email: "ada@example.com" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(error_json(
        "unprocessable_content",
        "Card number must be a six-digit number and Email has already been taken",
        "card_number" => [ "must be a six-digit number" ], "email" => [ "has already been taken" ]
      ))
    end

    it "returns 400 without reader attributes" do
      post readers_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "param is missing or the value is empty or invalid: reader"))
    end

    it "returns 400 for a malformed JSON body" do
      post readers_path, params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "Error occurred while parsing request parameters"))
    end

    it "ignores unknown reader attributes" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada", nickname: "Countess" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq("id" => Reader.sole.id, "card_number" => "123456", "name" => "Ada", "email" => nil)
    end

    it "doesn't let clients set attributes outside the permitted list" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada", discarded_at: Time.current } }, as: :json

      expect(response).to have_http_status(:created)
      expect(Reader.sole).to be_kept
    end

    it "returns 400 when reader is not an object" do
      post readers_path, params: { reader: "Ada" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "param is missing or the value is empty or invalid: reader"))
    end
  end

  describe "DELETE /readers/:id" do
    it "soft-deletes the reader" do
      reader = create(:reader)

      delete reader_path(reader)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(reader.reload).to be_discarded
    end

    it "returns 404 for an already deleted reader" do
      reader = create(:reader)
      reader.discard

      delete reader_path(reader)

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error_json("not_found", "Reader not found"))
    end

    it "returns 409 while the reader has a borrowed book" do
      reader = create(:reader)
      Borrowing.borrow!(book: create(:book), reader:)

      delete reader_path(reader)

      expect(response).to have_http_status(:conflict)
      expect(json).to eq(error_json("conflict", "Reader has borrowed books that are not returned"))
      expect(reader.reload).to be_kept
    end
  end
end
