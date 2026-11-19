# Expected API representations, so request specs compare whole response bodies with `eq`.
module ApiJson
  def reader_json(reader)
    { "id" => reader.id, "card_number" => reader.card_number, "name" => reader.name, "email" => reader.email }
  end

  def borrowing_json(borrowing)
    {
      "id" => borrowing.id,
      "borrowed_at" => borrowing.borrowed_at.iso8601,
      "due_on" => borrowing.due_on.iso8601,
      "returned_at" => borrowing.returned_at&.iso8601,
      "reader" => reader_json(borrowing.reader)
    }
  end

  def book_json(book, status:, current_borrowing: nil, borrowings: nil)
    json = {
      "id" => book.id,
      "serial_number" => book.serial_number,
      "title" => book.title,
      "author" => book.author,
      "status" => status,
      "current_borrowing" => current_borrowing && borrowing_json(current_borrowing)
    }
    json["borrowings"] = borrowings.map { |borrowing| borrowing_json(borrowing) } if borrowings
    json
  end

  def error_json(status, message, details = nil)
    { "error" => { "status" => status, "message" => message, "details" => details } }
  end
end

RSpec.configure do |config|
  config.include ApiJson, type: :request
end
