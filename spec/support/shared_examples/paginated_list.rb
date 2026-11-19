# Pagination behaviour of a list endpoint.
#
#   it_behaves_like "a paginated list", factory: :reader, order_by: "card_number" do
#     let(:path) { readers_path }
#   end
RSpec.shared_examples "a paginated list" do |factory:, order_by:|
  let(:json) { response.parsed_body }

  it "paginates with page and per_page" do
    values = create_list(factory, 5).map { |record| record.public_send(order_by) }.sort

    get path, params: { page: 2, per_page: 2 }

    expect(json.pluck(order_by)).to eq(values[2, 2])
  end

  it "returns 25 records per page by default" do
    create_list(factory, 26)

    get path

    expect(json.size).to eq(25)
  end

  it "accepts per_page up to 100" do
    create_list(factory, 101)

    get path, params: { per_page: 100 }

    expect(json.size).to eq(100)
  end

  [ "", "0", "-1", "abc", "1.5", " 2", "+2", "1_0" ].each do |page|
    it "rejects page=#{page.inspect} with 400" do
      get path, params: { page: }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "page must be a positive integer"))
    end
  end

  it "rejects a page whose offset exceeds the database integer range with 400" do
    get path, params: { page: "99999999999999999999" }

    expect(response).to have_http_status(:bad_request)
    expect(json).to eq(error_json("bad_request", "page is out of range"))
  end

  [ "", "0", "101", "-5", "many", "2.5" ].each do |per_page|
    it "rejects per_page=#{per_page.inspect} with 400" do
      get path, params: { per_page: }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq(error_json("bad_request", "per_page must be an integer between 1 and 100"))
    end
  end
end
