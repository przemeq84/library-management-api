require "rails_helper"

RSpec.describe Book do
  it "is valid with factory attributes" do
    expect(build(:book)).to be_valid
  end

  %i[serial_number title author].each do |attribute|
    it "requires #{attribute}" do
      book = build(:book, attribute => nil)

      expect(book).not_to be_valid
      expect(book.errors[attribute]).to eq([ "can't be blank" ])
    end
  end

  describe "serial_number" do
    %w[12345 1234567 12a456].each do |value|
      it "rejects #{value.inspect}" do
        book = build(:book, serial_number: value)

        expect(book).not_to be_valid
        expect(book.errors[:serial_number]).to include("must be a six-digit number")
      end
    end

    it "accepts a leading zero and keeps it" do
      book = create(:book, serial_number: "012345")

      expect(book.reload.serial_number).to eq("012345")
    end

    it "must be unique among kept books" do
      create(:book, serial_number: "222222")

      duplicate = build(:book, serial_number: "222222")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:serial_number]).to include("has already been taken")
    end

    it "can be reused after the book is discarded" do
      create(:book, serial_number: "222222").discard

      expect(create(:book, serial_number: "222222")).to be_persisted
    end
  end

  describe "database constraints" do
    it "rejects a duplicate kept serial number written past validations" do
      create(:book, serial_number: "222222")
      book = create(:book)

      expect { book.update_column(:serial_number, "222222") }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".kept" do
    it "excludes discarded books" do
      kept = create(:book)
      create(:book).discard

      expect(described_class.kept).to contain_exactly(kept)
    end
  end

  describe "#status" do
    it "is available without an active borrowing" do
      book = create(:book)
      create(:borrowing, :returned, book:)

      expect(book.status).to eq("available")
    end

    it "is borrowed with an active borrowing" do
      book = create(:book)
      create(:borrowing, book:)

      expect(book.status).to eq("borrowed")
    end
  end

  describe "#current_borrowing" do
    it "returns the active borrowing only" do
      book = create(:book)
      create(:borrowing, :returned, book:)
      active = create(:borrowing, book:)

      expect(book.current_borrowing).to eq(active)
    end

    it "returns nil if book available" do
      book = create(:book)
      create(:borrowing, :returned, book:)

      expect(book.current_borrowing).to be_nil
    end
  end

  describe "#discard!" do
    it "raises BookStillBorrowed while the book is borrowed" do
      book = create(:book)
      Borrowing.borrow!(book:, reader: create(:reader))

      expect { book.discard! }.to raise_error(Borrowing::Errors::BookStillBorrowed, "Book is currently borrowed")
      expect(book.reload).to be_kept
    end

    it "succeeds once the book is returned" do
      book = create(:book)
      reader = create(:reader)
      Borrowing.borrow!(book:, reader:)
      Borrowing.return!(book:, reader:)

      book.reload.discard!

      expect(book).to be_discarded
    end
  end
end
