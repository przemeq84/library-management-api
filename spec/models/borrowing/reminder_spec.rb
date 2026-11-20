require "rails_helper"

RSpec.describe Borrowing::Reminder do
  describe ".fetch" do
    it "finds a reminder by name" do
      expect(described_class.fetch("due_soon")).to eq(described_class::DUE_SOON)
    end

    it "accepts a symbol" do
      expect(described_class.fetch(:due_today)).to eq(described_class::DUE_TODAY)
    end

    it "rejects an unknown name" do
      expect { described_class.fetch("bogus") }.to raise_error(KeyError)
    end
  end

  describe "#due_on_range" do
    let(:today) { Date.new(2026, 6, 16) }

    it "covers the next 3 days for due_soon" do
      expect(described_class::DUE_SOON.due_on_range(today)).to eq(Date.new(2026, 6, 17)..Date.new(2026, 6, 19))
    end

    it "covers today and up to 7 overdue days for due_today" do
      expect(described_class::DUE_TODAY.due_on_range(today)).to eq(Date.new(2026, 6, 9)..Date.new(2026, 6, 16))
    end
  end

  describe "#sent_at_column" do
    it "returns due_soon_reminder_sent_at for due_soon" do
      expect(described_class::DUE_SOON.sent_at_column).to eq(:due_soon_reminder_sent_at)
    end

    it "returns due_today_reminder_sent_at for due_today" do
      expect(described_class::DUE_TODAY.sent_at_column).to eq(:due_today_reminder_sent_at)
    end
  end

  describe "#mailer_action" do
    it "returns due_soon for due_soon" do
      expect(described_class::DUE_SOON.mailer_action).to eq(:due_soon)
    end

    it "returns due_today for due_today" do
      expect(described_class::DUE_TODAY.mailer_action).to eq(:due_today)
    end
  end

  described_class::ALL.each_value do |reminder|
    context "with #{reminder.name}" do
      it "returns an existing borrowings column" do
        expect(Borrowing.column_names).to include(reminder.sent_at_column.to_s)
      end

      it "returns existing mailer action" do
        expect(ReminderMailer.action_methods).to include(reminder.mailer_action.to_s)
      end
    end
  end
end
