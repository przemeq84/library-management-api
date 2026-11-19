require "rails_helper"

RSpec.describe SendReminderJob do
  let(:reader) { create(:reader, email: "ada@example.com") }
  let(:borrowing) { create(:borrowing, reader:) }

  before { freeze_time }

  %w[due_soon due_today].each do |kind|
    describe kind do
      let(:column) { :"#{kind}_reminder_sent_at" }

      it "sends the reminder and records when it was sent" do
        expect { described_class.perform_now(borrowing, kind) }.to change(ActionMailer::Base.deliveries, :count).by(1)

        expect(ActionMailer::Base.deliveries.last.to).to eq([ "ada@example.com" ])
        expect(borrowing.reload.public_send(column)).to eq(Time.current)
      end

      it "sends nothing when the reminder was already sent" do
        described_class.perform_now(borrowing, kind)

        expect { described_class.perform_now(borrowing.reload, kind) }.not_to change(ActionMailer::Base.deliveries, :count)
      end

      it "neither sends nor records a reminder once the book is returned" do
        Borrowing.return!(book: borrowing.book, reader:)

        expect { described_class.perform_now(borrowing.reload, kind) }.not_to change(ActionMailer::Base.deliveries, :count)
        expect(borrowing.reload.public_send(column)).to be_nil
      end

      # A job loads the borrowing fresh when it's deserialized. These specs pass a borrowing loaded earlier
      # to simulate the window between that load and the claim, in which a concurrent process acts.
      context "when another process acts between loading the borrowing and claiming the reminder" do
        let!(:loaded_by_job) { Borrowing.find(borrowing.id) }

        it "sends nothing when a concurrent job for the same reminder claimed it first" do
          Borrowing.where(id: borrowing.id).update_all(column => 1.minute.ago)

          expect { described_class.perform_now(loaded_by_job, kind) }.not_to change(ActionMailer::Base.deliveries, :count)
          expect(borrowing.reload.public_send(column)).to eq(1.minute.ago)
        end

        it "sends nothing when the book was returned meanwhile" do
          Borrowing.return!(book: borrowing.book, reader:)

          expect { described_class.perform_now(loaded_by_job, kind) }.not_to change(ActionMailer::Base.deliveries, :count)
          expect(borrowing.reload.public_send(column)).to be_nil
        end
      end

      it "neither sends nor records a reminder when the reader has no email" do
        reader.update!(email: nil)

        expect { described_class.perform_now(borrowing.reload, kind) }.not_to change(ActionMailer::Base.deliveries, :count)
        expect(borrowing.reload.public_send(column)).to be_nil
      end

      it "releases the claim and retries when delivery fails" do
        allow(ReminderMailer).to receive(:with).and_raise(Net::SMTPServerBusy, "try again later")

        expect { described_class.perform_now(borrowing, kind) }
          .to have_enqueued_job(described_class).with(borrowing, kind)
        expect(borrowing.reload.public_send(column)).to be_nil
      end
    end
  end

  it "rejects an unknown reminder" do
    expect { described_class.perform_now(borrowing, "bogus") }.to raise_error(ArgumentError, "unknown reminder: \"bogus\"")
  end
end
