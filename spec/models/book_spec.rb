require "rails_helper"

RSpec.describe Book do
  describe "validations" do
    subject(:errors) { book.tap(&:validate).errors }

    let(:book) { build(:book) }

    it "accepts the factory attributes" do
      expect(errors).to be_empty
    end

    %i[serial_number title author].each do |attribute|
      context "without #{attribute}" do
        let(:book) { build(:book, attribute => nil) }

        it { expect(errors[attribute]).to eq([ "can't be blank" ]) }
      end
    end

    %w[12345 1234567 12a456].each do |value|
      context "with serial number #{value.inspect}" do
        let(:book) { build(:book, serial_number: value) }

        it { expect(errors[:serial_number]).to include("must be a six-digit number") }
      end
    end

    context "when a kept book has the same serial number" do
      let(:book) { build(:book, serial_number: "222222") }

      before { create(:book, serial_number: "222222") }

      it 'fails the validation' do
        expect(errors[:serial_number]).to include("has already been taken")
      end
    end

    context "when a discarded book has the same serial number" do
      let(:book) { build(:book, serial_number: "222222") }

      before { create(:book, serial_number: "222222").discard }

      it { expect(errors[:serial_number]).to include("has already been taken") }
    end
  end

  describe "#to_param" do
    subject { build(:book, serial_number: "012345").to_param }

    it { is_expected.to eq("012345") }
  end

  describe "#serial_number" do
    let(:book) { create(:book, serial_number: "012345") }

    it "keeps a leading zero" do
      expect(book.reload.serial_number).to eq("012345")
    end
  end

  describe "database constraints" do
    let(:book) { create(:book) }

    context "when a kept book has the same serial number" do
      before { create(:book, serial_number: "222222") }

      it "rejects it when written past validations" do
        expect { book.update_column(:serial_number, "222222") }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context "when a discarded book has the same serial number" do
      before { create(:book, serial_number: "222222").discard }

      it "rejects it when written past validations" do
        expect { book.update_column(:serial_number, "222222") }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe ".kept" do
    let(:kept) { create(:book) }

    before { create(:book).discard }

    it "excludes discarded books" do
      expect(described_class.kept).to contain_exactly(kept)
    end
  end

  describe "#status" do
    subject { book.status }

    let(:book) { create(:book) }

    context "when the book was only borrowed in the past" do
      before { create(:borrowing, :returned, book:) }

      it { is_expected.to eq("available") }
    end

    context "when the book is borrowed" do
      before { create(:borrowing, book:) }

      it { is_expected.to eq("borrowed") }
    end
  end

  describe "#current_borrowing" do
    subject { book.current_borrowing }

    let(:book) { create(:book) }

    before { create(:borrowing, :returned, book:) }

    context "when the book is borrowed" do
      let!(:active) { create(:borrowing, book:) }

      it { is_expected.to eq(active) }
    end

    context "when the book is available" do
      it { is_expected.to be_nil }
    end
  end

  describe "#borrowings_chronological" do
    let(:book) { create(:book) }
    let!(:older) { create(:borrowing, :returned, book:, borrowed_at: 2.months.ago) }
    let!(:current) { create(:borrowing, book:, borrowed_at: 1.day.ago) }
    let!(:oldest) { create(:borrowing, :returned, book:, borrowed_at: 3.months.ago) }

    before { create(:borrowing, :returned, borrowed_at: 1.week.ago) }

    it "lists the book's borrowings, newest first" do
      expect(book.borrowings_chronological).to eq([ current, older, oldest ])
    end
  end

  describe "#discard!" do
    let(:book) { create(:book) }
    let(:reader) { create(:reader) }

    context "when the book is borrowed" do
      before { Borrowing.borrow!(book:, reader:) }

      it "raises BookStillBorrowed and keeps the book" do
        expect { book.discard! }
          .to raise_error(Borrowing::Errors::BookStillBorrowed, "Book is currently borrowed")
          .and not_change { book.reload.kept? }.from(true)
      end
    end

    context "when the book has been returned" do
      before do
        Borrowing.borrow!(book:, reader:)
        Borrowing.return!(book:, reader:)
      end

      it "discards the book" do
        expect { book.reload.discard! }.to change(book, :discarded?).from(false).to(true)
      end
    end
  end
end
