require "rails_helper"

RSpec.describe "db:seed", type: :task do
  context "when loaded twice" do
    before do
      freeze_time
      2.times { Rails.application.load_seed }
    end

    it "creates the demo readers once" do
      expect(Reader.pluck(:name)).to contain_exactly(
        "Mario", "Lara Croft", "Geralt of Rivia", "Link", "Samus Aran", "Master Chief"
      )
    end

    it "leaves some readers without an email" do
      expect(Reader.where(email: nil).pluck(:name)).to contain_exactly("Link", "Master Chief")
    end

    it "creates the demo books once" do
      expect(Book.pluck(:title)).to contain_exactly(
        "Pride and Prejudice", "Moby-Dick", "Crime and Punishment", "Don Quixote",
        "Frankenstein", "Jane Eyre", "War and Peace", "The Odyssey"
      )
    end

    it "creates the demo borrowings once" do
      expect(Borrowing.count).to eq(3)
    end
  end
end
