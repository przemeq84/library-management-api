require "rails_helper"

RSpec.describe "Readers" do
  let(:json) { response.parsed_body }

  describe "GET /readers" do
    it "lists kept readers ordered by card number" do
      create(:reader, card_number: "000003", name: "Carol", email: nil)
      first = create(:reader, card_number: "000001", name: "Alice", email: "alice@example.com")
      create(:reader, card_number: "000002").discard

      get readers_path

      expect(response).to have_http_status(:ok)
      expect(json.pluck("card_number")).to eq(%w[000001 000003])
      expect(json.first).to eq(
        "id" => first.id, "card_number" => "000001", "name" => "Alice", "email" => "alice@example.com"
      )
    end

    it "paginates with page and per_page" do
      %w[000001 000002 000003 000004 000005].each { |number| create(:reader, card_number: number) }

      get readers_path, params: { page: 2, per_page: 2 }

      expect(json.pluck("card_number")).to eq(%w[000003 000004])
    end

    it "returns 25 readers per page by default" do
      create_list(:reader, 26)

      get readers_path

      expect(json.size).to eq(25)
    end

    it "accepts per_page up to 100" do
      create_list(:reader, 101)

      get readers_path, params: { per_page: 100 }

      expect(json.size).to eq(100)
    end

    [ "", "0", "-1", "abc", "1.5", " 2", "+2", "1_0" ].each do |page|
      it "rejects page=#{page.inspect} with 400" do
        get readers_path, params: { page: }

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]).to include("status" => "bad_request", "message" => "page must be a positive integer")
      end
    end

    it "rejects a page whose offset exceeds the database integer range with 400" do
      get readers_path, params: { page: "99999999999999999999" }

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to include("status" => "bad_request", "message" => "page is out of range")
    end

    [ "", "0", "101", "-5", "many", "2.5" ].each do |per_page|
      it "rejects per_page=#{per_page.inspect} with 400" do
        get readers_path, params: { per_page: }

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]).to include("status" => "bad_request",
                                         "message" => "per_page must be an integer between 1 and 100")
      end
    end
  end

  describe "POST /readers" do
    it "creates a reader" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada", email: " Ada@Example.com " } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("card_number" => "123456", "name" => "Ada", "email" => "ada@example.com")
      expect(Reader.find(json["id"]).name).to eq("Ada")
    end

    it "creates a reader without an email" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["email"]).to be_nil
    end

    it "returns 422 with validation details" do
      create(:reader, email: "ada@example.com")

      post readers_path, params: { reader: { card_number: "123", name: "Ada", email: "ada@example.com" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to include("status" => "unprocessable_content", "message" => be_present)
      expect(json.dig("error", "details")).to eq(
        "card_number" => [ "must be a six-digit number" ], "email" => [ "has already been taken" ]
      )
    end

    it "returns 400 without reader attributes" do
      post readers_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "status")).to eq("bad_request")
    end

    it "returns 400 for a malformed JSON body" do
      post readers_path, params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "status")).to eq("bad_request")
    end

    it "ignores unknown reader attributes" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada", nickname: "Countess" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json.keys).to contain_exactly("id", "card_number", "name", "email")
    end

    it "doesn't let clients set attributes outside the permitted list" do
      post readers_path, params: { reader: { card_number: "123456", name: "Ada", discarded_at: Time.current } }, as: :json

      expect(response).to have_http_status(:created)
      expect(Reader.find(json["id"])).to be_kept
    end

    it "returns 400 when reader is not an object" do
      post readers_path, params: { reader: "Ada" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "status")).to eq("bad_request")
    end
  end

  describe "DELETE /readers/:id" do
    it "soft-deletes the reader" do
      reader = create(:reader)

      delete reader_path(reader)

      expect(response).to have_http_status(:no_content)
      expect(reader.reload).to be_discarded
    end

    it "returns 404 for an already deleted reader" do
      reader = create(:reader)
      reader.discard

      delete reader_path(reader)

      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to include("status" => "not_found", "message" => "Reader not found")
    end

    it "returns 409 while the reader has a borrowed book" do
      reader = create(:reader)
      Borrowing.borrow!(book: create(:book), reader:)

      delete reader_path(reader)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to include("status" => "conflict", "message" => "Reader has borrowed books that are not returned")
      expect(reader.reload).to be_kept
    end
  end
end
