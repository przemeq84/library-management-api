require "rails_helper"

RSpec.describe Reader do
  it "is valid with factory attributes" do
    expect(build(:reader)).to be_valid
  end

  %i[card_number name].each do |attribute|
    it "requires #{attribute}" do
      reader = build(:reader, attribute => nil)

      expect(reader).not_to be_valid
      expect(reader.errors[attribute]).to eq([ "can't be blank" ])
    end
  end

  describe "card_number" do
    %w[12345 1234567 12a456].each do |value|
      it "rejects #{value.inspect}" do
        reader = build(:reader, card_number: value)

        expect(reader).not_to be_valid
        expect(reader.errors[:card_number]).to include("must be a six-digit number")
      end
    end

    it "accepts a leading zero and keeps it" do
      reader = create(:reader, card_number: "012345")

      expect(reader.reload.card_number).to eq("012345")
    end

    it "must be unique among kept readers" do
      create(:reader, card_number: "111111")

      duplicate = build(:reader, card_number: "111111")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:card_number]).to include("has already been taken")
    end

    it "can be reused after the reader is discarded" do
      create(:reader, card_number: "111111").discard

      expect(create(:reader, card_number: "111111")).to be_persisted
    end
  end

  describe "email" do
    it "is optional" do
      expect(build(:reader, email: nil)).to be_valid
    end

    it "normalizes blank to nil" do
      expect(build(:reader, email: "  ").email).to be_nil
    end

    it "normalizes case and surrounding whitespace" do
      expect(build(:reader, email: " Foo@Bar.COM ").email).to eq("foo@bar.com")
    end

    it "allows several readers without email" do
      create(:reader, email: nil)

      expect(create(:reader, email: nil)).to be_persisted
    end

    it "rejects a malformed address" do
      reader = build(:reader, email: "not-an-email")

      expect(reader).not_to be_valid
      expect(reader.errors[:email]).to include("is invalid")
    end

    it "must be unique among kept readers, ignoring case" do
      create(:reader, email: "foo@bar.com")

      duplicate = build(:reader, email: "FOO@bar.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end

    it "can be reused after the reader is discarded" do
      create(:reader, email: "foo@bar.com").discard

      expect(create(:reader, email: "foo@bar.com")).to be_persisted
    end
  end

  describe "database constraints" do
    it "rejects a duplicate kept email written past validations" do
      create(:reader, email: "foo@bar.com")
      reader = create(:reader)

      expect { reader.update_column(:email, "foo@bar.com") }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".kept" do
    it "excludes discarded readers" do
      kept = create(:reader)
      create(:reader).discard

      expect(described_class.kept).to contain_exactly(kept)
    end
  end

  describe "#discard!" do
    it "raises ReaderHasActiveBorrowings while the reader has an active borrowing" do
      reader = create(:reader)
      Borrowing.borrow!(book: create(:book), reader:)

      expect { reader.discard! }
        .to raise_error(Borrowing::Errors::ReaderHasActiveBorrowings, "Reader has borrowed books that are not returned")
      expect(reader.reload).to be_kept
    end

    it "succeeds once all books are returned" do
      reader = create(:reader)
      book = create(:book)
      Borrowing.borrow!(book:, reader:)
      Borrowing.return!(book:, reader:)

      reader.reload.discard!

      expect(reader).to be_discarded
    end
  end
end
