require "rails_helper"

RSpec.describe Borrowing do
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }

  describe ".borrow!" do
    subject(:borrowing) { described_class.borrow!(book:, reader:) }

    context "with a borrow time" do
      subject(:borrowing) { described_class.borrow!(book:, reader:, at:) }

      let(:at) { Time.zone.local(2026, 3, 10, 14, 0) }

      it { is_expected.to be_persisted }

      it "records the borrowing with a due date 30 days later" do
        expect(borrowing).to have_attributes(book:, reader:, borrowed_at: at, due_on: Date.new(2026, 4, 9), returned_at: nil)
      end
    end

    context "without a borrow time" do
      let(:now) { Time.zone.local(2026, 5, 20, 9, 15, 30) }

      before { travel_to now }

      it "borrows now" do
        expect(borrowing.reload).to have_attributes(borrowed_at: now, due_on: Date.new(2026, 6, 19))
      end
    end

    context "when the borrow time falls on another day in UTC" do
      subject(:borrowing) { described_class.borrow!(book:, reader:, at:) }

      # 00:30 on 2 January in Warsaw is still 1 January in UTC.
      let(:at) { Time.find_zone!("Europe/Warsaw").local(2026, 1, 2, 0, 30).utc }

      around { |example| Time.use_zone("Europe/Warsaw") { example.run } }

      it "computes the due date from the local day in the application time zone" do
        expect(borrowing.due_on).to eq(Date.new(2026, 2, 1))
      end
    end

    it "marks the book as borrowed" do
      expect { borrowing }.to change { book.reload.status }.from("available").to("borrowed")
    end

    context "when the book is already borrowed" do
      before { described_class.borrow!(book:, reader: create(:reader)) }

      it { expect { borrowing }.to raise_error(Borrowing::Errors::AlreadyBorrowed) }
    end

    context "when a concurrent borrowing wins the active-borrowing unique index" do
      # Simulate a concurrent request that passed the availability check, then committed its insert first.
      before do
        allow(described_class).to receive(:create!).and_wrap_original do |original, **attributes|
          create(:borrowing, book:)
          original.call(**attributes)
        end
      end

      it { expect { borrowing }.to raise_error(Borrowing::Errors::AlreadyBorrowed) }
    end

    context "when the book is discarded" do
      before { book.discard }

      it { expect { borrowing }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context "when the reader is discarded" do
      before { reader.discard }

      it { expect { borrowing }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end

  describe ".return!" do
    subject(:borrowing) { described_class.return!(book:, reader:) }

    context "when the reader has the book" do
      subject(:borrowing) { described_class.return!(book:, reader:, at:) }

      let(:at) { 3.days.from_now }

      before { described_class.borrow!(book:, reader:) }

      it "records the return time" do
        expect(borrowing.returned_at).to be_within(1.second).of(at)
      end

      it "makes the book available again" do
        expect { borrowing }.to change { book.reload.status }.from("borrowed").to("available")
      end

      it "allows the book to be borrowed again" do
        borrowing

        expect { described_class.borrow!(book:, reader:) }.to change(book.borrowings, :count).from(1).to(2)
      end
    end

    context "without a return time" do
      let(:now) { Time.zone.local(2026, 5, 20, 16, 45, 10) }

      before do
        described_class.borrow!(book:, reader:, at: Time.zone.local(2026, 5, 1, 10, 0))
        travel_to now
      end

      it "records returned_time as now" do
        expect(borrowing.reload.returned_at).to eq(now)
      end
    end

    context "when the book is available" do
      it { expect { borrowing }.to raise_error(Borrowing::Errors::NotBorrowed, "Book is not borrowed") }
    end

    context "when the book is borrowed by another reader" do
      let!(:other_borrowing) { described_class.borrow!(book:, reader: create(:reader)) }

      it "raises NotBorrowed and keeps the borrowing active and keeps borrowing active" do
        expect { borrowing }
          .to raise_error(Borrowing::Errors::NotBorrowed, "Book borrowed by another reader")
          .and not_change { other_borrowing.reload.active? }.from(true)
      end
    end
  end

  describe ".active" do
    let(:active) { create(:borrowing) }

    before { create(:borrowing, :returned) }

    it "returns only borrowings that are not returned" do
      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe ".chronological" do
    let!(:older) { create(:borrowing, :returned, borrowed_at: 2.months.ago) }
    let!(:newer) { create(:borrowing, :returned, borrowed_at: 1.month.ago) }
    let!(:oldest) { create(:borrowing, :returned, borrowed_at: 3.months.ago) }

    it "orders by borrowed_at, newest first" do
      expect(described_class.chronological).to eq([ newer, older, oldest ])
    end
  end

  describe "#remindable?" do
    context "when active and the reader has an email" do
      subject { build(:borrowing) }

      it { is_expected.to be_remindable }
    end

    context "when the book is returned" do
      subject { build(:borrowing, :returned) }

      it { is_expected.not_to be_remindable }
    end

    context "when the reader has no email" do
      subject { build(:borrowing, reader: build(:reader, email: nil)) }

      it { is_expected.not_to be_remindable }
    end
  end

  describe "#active?" do
    context "when the book is not returned" do
      subject { build(:borrowing) }

      it { is_expected.to be_active }
    end

    context "when the book is returned" do
      subject { build(:borrowing, :returned) }

      it { is_expected.not_to be_active }
    end
  end

  describe "#claim_reminder" do
    subject(:claim) { borrowing.claim_reminder(reminder) }

    let(:borrowing) { create(:borrowing) }
    let(:reminder) { Borrowing::Reminder::DUE_SOON }

    before { freeze_time }

    context "with reminder not sent yet" do
      it { is_expected.to be(true) }

      it "records the reminder as sent now" do
        expect { claim }.to change { borrowing.reload.due_soon_reminder_sent_at }.from(nil).to(Time.current)
      end
    end

    it "leaves the other reminder unclaimed" do
      expect { claim }.not_to change { borrowing.reload.due_today_reminder_sent_at }.from(nil)
    end

    context "when the reminder was already sent" do
      let(:borrowing) { create(:borrowing, due_soon_reminder_sent_at: 1.day.ago) }

      it { is_expected.to be(false) }

      it "keeps the original sent time" do
        expect { claim }.not_to change { borrowing.reload.due_soon_reminder_sent_at }.from(1.day.ago)
      end
    end

    context "when another process claimed it after the borrowing was loaded" do
      before { described_class.where(id: borrowing.id).update_all(due_soon_reminder_sent_at: 1.minute.ago) }

      it { is_expected.to be(false) }

      it "keeps the other claim" do
        expect { claim }.not_to change { borrowing.reload.due_soon_reminder_sent_at }.from(1.minute.ago)
      end
    end

    context "when the book is returned" do
      let(:borrowing) { create(:borrowing, :returned) }

      it { is_expected.to be(false) }

      it "records nothing" do
        expect { claim }.not_to change { borrowing.reload.due_soon_reminder_sent_at }.from(nil)
      end
    end

    context "when the reader has no email" do
      let(:borrowing) { create(:borrowing, reader: create(:reader, email: nil)) }

      it { is_expected.to be(false) }

      it "records nothing" do
        expect { claim }.not_to change { borrowing.reload.due_soon_reminder_sent_at }.from(nil)
      end
    end
  end

  describe "#release_reminder" do
    subject(:release) { borrowing.release_reminder(reminder) }

    let(:borrowing) { create(:borrowing, due_soon_reminder_sent_at: 1.hour.ago, due_today_reminder_sent_at: 1.hour.ago) }
    let(:reminder) { Borrowing::Reminder::DUE_SOON }

    before { freeze_time }

    it "clears the reminder's sent time" do
      expect { release }.to change { borrowing.reload.due_soon_reminder_sent_at }.from(1.hour.ago).to(nil)
    end

    it "leaves the other reminder's sent time" do
      expect { release }.not_to change { borrowing.reload.due_today_reminder_sent_at }.from(1.hour.ago)
    end

    it "lets the reminder be claimed again" do
      release

      expect(borrowing.claim_reminder(reminder)).to be(true)
    end
  end

  describe "database constraints" do
    it "allows only one active borrowing per book" do
      create(:borrowing, book:)

      expect { create(:borrowing, book:) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
