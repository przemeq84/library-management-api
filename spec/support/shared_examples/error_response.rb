# The API's error matcher for a request already made in a `before` block.
RSpec.shared_examples "an error response" do |status, message, details = nil|
  it { expect(response).to have_http_status(status) }

  it "describes the error" do
    expect(response.parsed_body).to eq(error_json(status.to_s, message, details))
  end
end
