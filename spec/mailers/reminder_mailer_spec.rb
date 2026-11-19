require "rails_helper"

RSpec.describe ReminderMailer do
  let(:reader) { create(:reader, name: "Ada Lovelace", email: "ada@example.com") }
  let(:book) { create(:book, title: "Emma", author: "Jane Austen", serial_number: "000042") }
  let!(:borrowing) do
    create(:borrowing, book:, reader:, borrowed_at: Time.zone.local(2026, 5, 20, 9, 0), due_on: Date.new(2026, 6, 19))
  end

  describe "#due_soon" do
    subject(:mail) { described_class.with(borrowing:).due_soon }

    it "reminds the reader that the book is due in a few days" do
      expect(mail.from).to eq([ "library@example.com" ])
      expect(mail.to).to eq([ "ada@example.com" ])
      expect(mail.subject).to eq("Reminder: \"Emma\" is due on June 19, 2026")
      expect(mail.text_part.decoded).to eq(<<~TEXT)
        Hello Ada Lovelace,

        This is a reminder that "Emma" by Jane Austen (serial number 000042) is due back on June 19, 2026.

        Thank you,
        Your library
      TEXT
      expect(mail.html_part.decoded).to include("<strong>Emma</strong> by Jane Austen", "June 19, 2026")
    end
  end

  describe "#due_today" do
    subject(:mail) { described_class.with(borrowing:).due_today }

    it "reminds the reader that the book is due today" do
      travel_to Date.new(2026, 6, 19).in_time_zone.change(hour: 8)

      expect(mail.to).to eq([ "ada@example.com" ])
      expect(mail.subject).to eq("Reminder: \"Emma\" is due today")
      expect(mail.text_part.decoded).to eq(<<~TEXT)
        Hello Ada Lovelace,

        "Emma" by Jane Austen (serial number 000042) is due back today, June 19, 2026. Please return it to the library.

        Thank you,
        Your library
      TEXT
      expect(mail.html_part.decoded).to include("<strong>Emma</strong> by Jane Austen", "June 19, 2026")
    end

    it "tells the reader the book is overdue when the reminder is caught up after the due date" do
      travel_to Date.new(2026, 6, 21).in_time_zone.change(hour: 8)

      expect(mail.subject).to eq("Reminder: \"Emma\" was due on June 19, 2026")
      expect(mail.text_part.decoded).to eq(<<~TEXT)
        Hello Ada Lovelace,

        "Emma" by Jane Austen (serial number 000042) was due back on June 19, 2026. Please return it to the library as soon as possible.

        Thank you,
        Your library
      TEXT
      expect(mail.html_part.decoded).to include("<strong>Emma</strong> by Jane Austen", "was due back on June 19, 2026")
    end
  end

  %i[due_soon due_today].each do |action|
    describe "##{action} when the reminder is no longer relevant" do
      it "sends nothing once the book has been returned" do
        Borrowing.return!(book:, reader:)

        expect { described_class.with(borrowing: borrowing.reload).public_send(action).deliver_now }
          .not_to change(ActionMailer::Base.deliveries, :count)
      end

      it "sends nothing when the reader has no email" do
        reader.update!(email: nil)

        expect { described_class.with(borrowing:).public_send(action).deliver_now }
          .not_to change(ActionMailer::Base.deliveries, :count)
      end
    end
  end
end
