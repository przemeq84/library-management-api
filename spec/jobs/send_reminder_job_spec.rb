require "rails_helper"

RSpec.describe SendReminderJob do
  subject(:perform) { described_class.perform_now(borrowing, kind) }

  let(:reader) { create(:reader, email: "ada@example.com") }
  let(:borrowing) { create(:borrowing, reader:) }

  before { freeze_time }

  %w[due_soon due_today].each do |reminder|
    context "with #{reminder}" do
      let(:kind) { reminder }
      let(:sent_at) { borrowing.reload.public_send(:"#{reminder}_reminder_sent_at") }

      it "sends the reminder" do
        expect { perform }.to change(ActionMailer::Base.deliveries, :count).by(1)
      end

      it "addresses the reminder to the reader" do
        perform

        expect(ActionMailer::Base.deliveries.last.to).to eq([ "ada@example.com" ])
      end

      it "records when it was sent" do
        perform

        expect(sent_at).to eq(Time.current)
      end

      context "when the reminder was already sent" do
        before do
          described_class.perform_now(borrowing, kind)
          borrowing.reload
        end

        it { expect { perform }.not_to change(ActionMailer::Base.deliveries, :count) }
      end

      context "when the book has been returned" do
        before do
          Borrowing.return!(book: borrowing.book, reader:)
          borrowing.reload
        end

        it "neither sends email nor records a reminder" do
          expect { perform }.to not_change(ActionMailer::Base.deliveries, :count).and not_change { sent_at }.from(nil)
        end
      end

      context "when the reader has no email" do
        before { reader.update!(email: nil) }

        it "neither sends email nor records a reminder" do
          expect { perform }.to not_change(ActionMailer::Base.deliveries, :count).and not_change { sent_at }.from(nil)
        end
      end

      # A job loads the borrowing fresh when it's deserialized. These contexts pass a borrowing loaded earlier
      # to simulate the window between that load and the claim, in which a concurrent process acts.
      context "when a concurrent job claimed the reminder after the borrowing was loaded" do
        subject(:perform) { described_class.perform_now(loaded_by_job, kind) }

        let!(:loaded_by_job) { Borrowing.find(borrowing.id) }

        before { Borrowing.where(id: borrowing.id).update_all("#{reminder}_reminder_sent_at" => 1.minute.ago) }

        it "sends nothing and keeps the concurrent claim" do
          expect { perform }.to not_change(ActionMailer::Base.deliveries, :count).and not_change { sent_at }.from(1.minute.ago)
        end
      end

      context "when the book was returned after the borrowing was loaded" do
        subject(:perform) { described_class.perform_now(loaded_by_job, kind) }

        let!(:loaded_by_job) { Borrowing.find(borrowing.id) }

        before { Borrowing.return!(book: borrowing.book, reader:) }

        it "neither sends email nor records a reminder" do
          expect { perform }.to not_change(ActionMailer::Base.deliveries, :count).and not_change { sent_at }.from(nil)
        end
      end

      context "when delivery fails" do
        before { allow(ReminderMailer).to receive(:with).and_raise(Net::SMTPServerBusy, "try again later") }

        it "releases the claim and retries" do
          expect { perform }
            .to have_enqueued_job(described_class).with(borrowing, kind)
            .and not_change { sent_at }.from(nil)
        end
      end
    end
  end

  context "with an unknown reminder" do
    let(:kind) { "bogus" }

    it { expect { perform }.to raise_error(ArgumentError, "unknown reminder: \"bogus\"") }
  end
end
