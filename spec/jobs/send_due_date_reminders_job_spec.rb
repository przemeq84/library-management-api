require "rails_helper"

RSpec.describe SendDueDateRemindersJob do
  let(:today) { Date.new(2026, 6, 16) }

  around { |example| travel_to(today.in_time_zone.change(hour: 8)) { example.run } }

  def borrowing_due(due_on, **attributes)
    create(:borrowing, borrowed_at: (due_on - 30).in_time_zone, due_on:, **attributes)
  end

  describe "due_soon" do
    it "enqueues a reminder job per borrowing due within 3 days, without marking it" do
      in_three_days = borrowing_due(today + 3)
      tomorrow = borrowing_due(today + 1)

      expect { described_class.perform_now("due_soon") }
        .to have_enqueued_job(SendReminderJob).with(in_three_days, "due_soon")
        .and have_enqueued_job(SendReminderJob).with(tomorrow, "due_soon")

      expect(in_three_days.reload.due_soon_reminder_sent_at).to be_nil
    end

    it "skips borrowings already reminded, not due within 3 days, due today, returned or without a reader email" do
      borrowing_due(today + 2, due_soon_reminder_sent_at: 1.day.ago)
      borrowing_due(today + 4)
      borrowing_due(today)
      borrowing_due(today + 2, returned_at: Time.current)
      borrowing_due(today + 2, reader: create(:reader, email: nil))

      expect { described_class.perform_now("due_soon") }.not_to have_enqueued_job(SendReminderJob)
    end
  end

  describe "due_today" do
    it "enqueues a reminder job for books due today and books overdue by up to 7 days never reminded" do
      due_today = borrowing_due(today)
      overdue = borrowing_due(today - 7)

      expect { described_class.perform_now("due_today") }
        .to have_enqueued_job(SendReminderJob).with(due_today, "due_today")
        .and have_enqueued_job(SendReminderJob).with(overdue, "due_today")
    end

    it "skips borrowings already reminded, overdue by more than 7 days, due later, returned or without a reader email" do
      borrowing_due(today, due_today_reminder_sent_at: 1.hour.ago)
      borrowing_due(today - 8)
      borrowing_due(today + 1)
      borrowing_due(today, returned_at: Time.current)
      borrowing_due(today, reader: create(:reader, email: nil))

      expect { described_class.perform_now("due_today") }.not_to have_enqueued_job(SendReminderJob)
    end
  end

  it "rejects an unknown reminder scope" do
    expect { described_class.perform_now("bogus") }.to raise_error(ArgumentError, "unknown reminder: \"bogus\"")
  end
end
