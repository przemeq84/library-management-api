require "rails_helper"

RSpec.describe Borrowing do
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }

  describe ".borrow!" do
    it "records the borrowing with a due date 30 days later" do
      at = Time.zone.local(2026, 3, 10, 14, 0)

      borrowing = described_class.borrow!(book:, reader:, at:)

      expect(borrowing).to be_persisted
      expect(borrowing).to have_attributes(book:, reader:, borrowed_at: at, due_on: Date.new(2026, 4, 9), returned_at: nil)
    end

    it "defaults the borrow time to now" do
      now = Time.zone.local(2026, 5, 20, 9, 15, 30)
      travel_to now do
        borrowing = described_class.borrow!(book:, reader:)

        expect(borrowing.reload).to have_attributes(borrowed_at: now,
                                                    due_on: Date.new(2026, 6, 19))
      end
    end

    it "computes the due date from the local day in the application time zone" do
      Time.use_zone("Europe/Warsaw") do
        # 00:30 on 2 January in Warsaw is still 1 January in UTC.
        at = Time.zone.local(2026, 1, 2, 0, 30)

        borrowing = described_class.borrow!(book:, reader:, at: at.utc)

        expect(borrowing.due_on).to eq(Date.new(2026, 2, 1))
      end
    end

    it "marks the book as borrowed" do
      described_class.borrow!(book:, reader:)

      expect(book.reload.status).to eq("borrowed")
    end

    it "raises AlreadyBorrowed when the book is already borrowed" do
      described_class.borrow!(book:, reader:)

      expect { described_class.borrow!(book:, reader: create(:reader)) }.to raise_error(Borrowing::Errors::AlreadyBorrowed)
    end

    it "raises AlreadyBorrowed when a concurrent borrowing wins the active-borrowing unique index" do
      create(:borrowing, book:)
      # Simulate a concurrent request that passed the availability check before the other insert committed.
      allow_any_instance_of(Book).to receive(:borrowed?).and_return(false)

      expect { described_class.borrow!(book:, reader:) }.to raise_error(Borrowing::Errors::AlreadyBorrowed)
    end

    it "raises RecordNotFound for a discarded book" do
      book.discard

      expect { described_class.borrow!(book:, reader:) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises RecordNotFound for a discarded reader" do
      reader.discard

      expect { described_class.borrow!(book:, reader:) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".return!" do
    it "sets returned_at and makes the book available again" do
      described_class.borrow!(book:, reader:)
      at = 3.days.from_now

      borrowing = described_class.return!(book:, reader:, at:)

      expect(borrowing.returned_at).to be_within(1.second).of(at)
      expect(book.reload.status).to eq("available")
    end

    it "defaults the return time to now" do
      described_class.borrow!(book:, reader:, at: Time.zone.local(2026, 5, 1, 10, 0))

      now = Time.zone.local(2026, 5, 20, 16, 45, 10)
      travel_to now do
        borrowing = described_class.return!(book:, reader:)

        expect(borrowing.reload.returned_at).to eq(now)
      end
    end

    it "raises NotBorrowed when the book is available" do
      expect { described_class.return!(book:, reader:) }.to raise_error(Borrowing::Errors::NotBorrowed, "Book is not borrowed")
    end

    it "raises NotBorrowed when the book is borrowed by another reader" do
      borrowing = described_class.borrow!(book:, reader:)

      expect { described_class.return!(book:, reader: create(:reader)) }
        .to raise_error(Borrowing::Errors::NotBorrowed, "Book borrowed by another reader")
      expect(borrowing.reload).to be_active
    end

    it "allows the book to be borrowed again" do
      described_class.borrow!(book:, reader:)
      described_class.return!(book:, reader:)

      expect(described_class.borrow!(book:, reader:)).to be_persisted
      expect(book.borrowings.count).to eq(2)
    end
  end

  describe "scopes" do
    it ".active returns only borrowings that are not returned" do
      active = create(:borrowing)
      create(:borrowing, :returned)

      expect(described_class.active).to contain_exactly(active)
    end

    it ".chronological orders by borrowed_at, newest first" do
      older = create(:borrowing, :returned, borrowed_at: 2.months.ago)
      newer = create(:borrowing, :returned, borrowed_at: 1.month.ago)
      oldest = create(:borrowing, :returned, borrowed_at: 3.months.ago)

      expect(described_class.chronological).to eq([ newer, older, oldest ])
    end
  end

  describe "#active?" do
    it "is true until the book is returned" do
      expect(build(:borrowing)).to be_active
      expect(build(:borrowing, :returned)).not_to be_active
    end
  end

  describe "database constraints" do
    it "allows only one active borrowing per book" do
      create(:borrowing, book:)

      expect { create(:borrowing, book:) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
