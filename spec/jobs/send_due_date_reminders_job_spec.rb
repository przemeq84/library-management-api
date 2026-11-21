require "rails_helper"

RSpec.describe SendDueDateRemindersJob do
  subject(:perform) { described_class.perform_now(reminder) }

  let(:today) { Date.new(2026, 6, 16) }

  before do
    travel_to(today.in_time_zone.change(hour: 8))
  end

  def borrowing_due(due_on, *traits, **attributes)
    create(:borrowing, *traits, borrowed_at: (due_on - 30).in_time_zone, due_on:, **attributes)
  end

  context "with due_soon" do
    let(:reminder) { "due_soon" }

    context "when borrowings are due within 3 days" do
      let!(:in_three_days) { borrowing_due(today + 3) }
      let!(:tomorrow) { borrowing_due(today + 1) }

      it "enqueues a reminder job per borrowing" do
        expect { perform }
          .to have_enqueued_job(SendReminderJob).with(in_three_days, "due_soon")
          .and have_enqueued_job(SendReminderJob).with(tomorrow, "due_soon")
      end

      it "leaves marking the reminder as sent to the reminder job" do
        expect { perform }.not_to change { in_three_days.reload.due_soon_reminder_sent_at }.from(nil)
      end
    end

    context "when the reminder was already sent" do
      before { borrowing_due(today + 2, due_soon_reminder_sent_at: 1.day.ago) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the borrowing is due in more than 3 days" do
      before { borrowing_due(today + 4) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the borrowing is due today" do
      before { borrowing_due(today) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the book is returned" do
      before { borrowing_due(today + 2, :returned, returned_at: Time.current) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the reader has no email" do
      before { borrowing_due(today + 2, reader: create(:reader, email: nil)) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end
  end

  context "with due_today" do
    let(:reminder) { "due_today" }

    context "when borrowings are due today or overdue by up to 7 days" do
      let!(:due_today) { borrowing_due(today) }
      let!(:overdue) { borrowing_due(today - 7) }

      it "enqueues a reminder job per borrowing" do
        expect { perform }
          .to have_enqueued_job(SendReminderJob).with(due_today, "due_today")
          .and have_enqueued_job(SendReminderJob).with(overdue, "due_today")
      end
    end

    context "when the reminder was already sent" do
      before { borrowing_due(today, due_today_reminder_sent_at: 1.hour.ago) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the borrowing is overdue by more than 7 days" do
      before { borrowing_due(today - 8) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the borrowing is due later" do
      before { borrowing_due(today + 1) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the book is returned" do
      before { borrowing_due(today, :returned, returned_at: Time.current) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end

    context "when the reader has no email" do
      before { borrowing_due(today, reader: create(:reader, email: nil)) }

      it { expect { perform }.not_to have_enqueued_job(SendReminderJob) }
    end
  end

  context "with an unknown reminder" do
    let(:reminder) { "bogus" }

    it { expect { perform }.to raise_error(KeyError) }
  end
end
