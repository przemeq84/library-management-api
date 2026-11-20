require "rails_helper"

RSpec.describe ReminderMailer do
  let(:reader) { create(:reader, name: "Ada Lovelace", email: "ada@example.com") }
  let(:book) { create(:book, title: "Emma", author: "Jane Austen", serial_number: "000042") }
  let(:borrowing) do
    create(:borrowing, book:, reader:, borrowed_at: Time.zone.local(2026, 5, 20, 9, 0), due_on: Date.new(2026, 6, 19))
  end

  shared_examples "a reminder that is no longer relevant" do
    context "when the book has been returned" do
      let(:borrowing) do
        create(:borrowing, book:, reader:,
               borrowed_at: Time.zone.local(2026, 5, 20, 9, 0),
               due_on: Date.new(2026, 6, 19),
               returned_at: Time.zone.local(2026, 5, 25, 14, 0))
      end

      it "sends nothing" do
        expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
      end
    end

    context "when the reader has no email" do
      let(:reader) { create(:reader, name: "Ada Lovelace", email: nil) }

      it "sends nothing" do
        expect { mail.deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
      end
    end
  end

  describe "#due_soon" do
    subject(:mail) { described_class.with(borrowing:).due_soon }

    it { expect(mail.from).to eq([ "library@example.com" ]) }

    it { expect(mail.to).to eq([ "ada@example.com" ]) }

    it { expect(mail.subject).to eq("Reminder: \"Emma\" is due on June 19, 2026") }

    it "reminds the reader that the book is due in a few days" do
      expect(mail.text_part.decoded).to eq(<<~TEXT)
        Hello Ada Lovelace,

        This is a reminder that "Emma" by Jane Austen (serial number 000042) is due back on June 19, 2026.

        Thank you,
        Your library
      TEXT
    end

    it "has an HTML part" do
      expect(mail.html_part.decoded).to include("<strong>Emma</strong> by Jane Austen", "June 19, 2026")
    end

    it_behaves_like "a reminder that is no longer relevant"
  end

  describe "#due_today" do
    subject(:mail) { described_class.with(borrowing:).due_today }

    context "when sent on the due date" do
      before { travel_to Date.new(2026, 6, 19).in_time_zone.change(hour: 8) }

      it { expect(mail.to).to eq([ "ada@example.com" ]) }

      it { expect(mail.subject).to eq("Reminder: \"Emma\" is due today") }

      it "reminds the reader that the book is due today" do
        expect(mail.text_part.decoded).to eq(<<~TEXT)
          Hello Ada Lovelace,

          "Emma" by Jane Austen (serial number 000042) is due back today, June 19, 2026. Please return it to the library.

          Thank you,
          Your library
        TEXT
      end

      it "has an HTML part" do
        expect(mail.html_part.decoded).to include("<strong>Emma</strong> by Jane Austen", "June 19, 2026")
      end
    end

    context "when sent after the due date" do
      before { travel_to Date.new(2026, 6, 21).in_time_zone.change(hour: 8) }

      it { expect(mail.subject).to eq("Reminder: \"Emma\" was due on June 19, 2026") }

      it "tells the reader the book is overdue" do
        expect(mail.text_part.decoded).to eq(<<~TEXT)
          Hello Ada Lovelace,

          "Emma" by Jane Austen (serial number 000042) was due back on June 19, 2026. Please return it to the library as soon as possible.

          Thank you,
          Your library
        TEXT
      end

      it "has an HTML part" do
        expect(mail.html_part.decoded).to include("<strong>Emma</strong> by Jane Austen", "was due back on June 19, 2026")
      end
    end

    it_behaves_like "a reminder that is no longer relevant"
  end
end
