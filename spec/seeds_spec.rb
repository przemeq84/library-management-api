require "rails_helper"

RSpec.describe "db/seeds.rb" do
  before do
    freeze_time
    2.times { Rails.application.load_seed }
  end

  let(:today) { Time.zone.today }

  it "creates the demo readers and books once, even when loaded twice" do
    expect(Reader.pluck(:name)).to contain_exactly(
      "Mario", "Lara Croft", "Geralt of Rivia", "Link", "Samus Aran", "Master Chief"
    )
    expect(Reader.where(email: nil).pluck(:name)).to contain_exactly("Link", "Master Chief")
    expect(Book.pluck(:title)).to contain_exactly(
      "Pride and Prejudice", "Moby-Dick", "Crime and Punishment", "Don Quixote",
      "Frankenstein", "Jane Eyre", "War and Peace", "The Odyssey"
    )
    expect(Borrowing.count).to eq(3)
  end
end
