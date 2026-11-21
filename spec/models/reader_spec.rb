require "rails_helper"

RSpec.describe Reader do
  describe "validations" do
    subject(:errors) { reader.tap(&:validate).errors }

    let(:reader) { build(:reader) }

    it "accepts the factory attributes" do
      expect(errors).to be_empty
    end

    %i[card_number name].each do |attribute|
      context "without #{attribute}" do
        let(:reader) { build(:reader, attribute => nil) }

        it { expect(errors[attribute]).to eq([ "can't be blank" ]) }
      end
    end

    %w[12345 1234567 12a456].each do |value|
      context "with card number #{value.inspect}" do
        let(:reader) { build(:reader, card_number: value) }

        it { expect(errors[:card_number]).to include("must be a six-digit number") }
      end
    end

    context "when a kept reader has the same card number" do
      let(:reader) { build(:reader, card_number: "111111") }

      before { create(:reader, card_number: "111111") }

      it { expect(errors[:card_number]).to include("has already been taken") }
    end

    context "when a discarded reader has the same card number" do
      let(:reader) { build(:reader, card_number: "111111") }

      before { create(:reader, card_number: "111111").discard }

      it { expect(errors[:card_number]).to include("has already been taken") }
    end

    context "without email" do
      let(:reader) { build(:reader, email: nil) }

      it { expect(errors).to be_empty }
    end

    context "with a malformed email" do
      let(:reader) { build(:reader, email: "not-an-email") }

      it { expect(errors[:email]).to include("is invalid") }
    end

    context "when a kept reader has the same email in another case" do
      let(:reader) { build(:reader, email: "FOO@bar.com") }

      before { create(:reader, email: "foo@bar.com") }

      it { expect(errors[:email]).to include("has already been taken") }
    end

    context "when a discarded reader has the same email" do
      let(:reader) { build(:reader, email: "foo@bar.com") }

      before { create(:reader, email: "foo@bar.com").discard }

      it "allows the email to be reused" do
        expect(reader.save).to be(true)
      end
    end

    context "when another reader has no email either" do
      let(:reader) { build(:reader, email: nil) }

      before { create(:reader, email: nil) }

      it "allows both to be saved" do
        expect(reader.save).to be(true)
      end
    end
  end

  describe "#card_number" do
    let(:reader) { create(:reader, card_number: "012345") }

    it "keeps a leading zero" do
      expect(reader.reload.card_number).to eq("012345")
    end
  end

  describe "#to_param" do
    subject { build(:reader, card_number: "012345").to_param }

    it { is_expected.to eq("012345") }
  end

  describe "#email" do
    it "normalizes blank to nil" do
      expect(build(:reader, email: "  ").email).to be_nil
    end

    it "normalizes case and surrounding whitespace" do
      expect(build(:reader, email: " Foo@Bar.COM ").email).to eq("foo@bar.com")
    end
  end

  describe "database constraints" do
    let(:reader) { create(:reader) }

    context "when a kept reader has the same email" do
      before { create(:reader, email: "foo@bar.com") }

      it "rejects it when written past validations" do
        expect { reader.update_column(:email, "foo@bar.com") }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context "when a discarded reader has the same card number" do
      before { create(:reader, card_number: "111111").discard }

      it "rejects it when written past validations" do
        expect { reader.update_column(:card_number, "111111") }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe ".kept" do
    let(:kept) { create(:reader) }

    before { create(:reader).discard }

    it "excludes discarded readers" do
      expect(described_class.kept).to contain_exactly(kept)
    end
  end

  describe "#discard!" do
    let(:reader) { create(:reader) }
    let(:book) { create(:book) }

    context "when the reader has a borrowed book" do
      before { Borrowing.borrow!(book:, reader:) }

      it "raises ReaderHasActiveBorrowings and keeps the reader" do
        expect { reader.discard! }
          .to raise_error(Borrowing::Errors::ReaderHasActiveBorrowings, "Reader has borrowed books that are not returned")
          .and not_change { reader.reload.kept? }.from(true)
      end
    end

    context "when all books have been returned" do
      before do
        Borrowing.borrow!(book:, reader:)
        Borrowing.return!(book:, reader:)
      end

      it "discards the reader" do
        expect { reader.reload.discard! }.to change(reader, :discarded?).from(false).to(true)
      end
    end
  end
end
