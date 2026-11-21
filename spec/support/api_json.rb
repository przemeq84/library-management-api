# Expected API representations, so request specs compare whole response bodies with `eq`.
module ApiJson
  def reader_json(reader)
    { "card_number" => reader.card_number, "name" => reader.name, "email" => reader.email }
  end

  def borrowing_json(borrowing)
    {
      "id" => borrowing.id,
      "status" => borrowing.status,
      "borrowed_at" => borrowing.borrowed_at.iso8601,
      "due_on" => borrowing.due_on.iso8601,
      "returned_at" => borrowing.returned_at&.iso8601,
      "reader" => reader_json(borrowing.reader)
    }
  end

  # Pass recent_borrowings for the detailed view (GET /books/:serial_number and borrow/return responses).
  def book_json(book, status:, current_borrowing: nil, recent_borrowings: nil,
                borrowings_count: recent_borrowings&.size)
    json = {
      "serial_number" => book.serial_number,
      "title" => book.title,
      "author" => book.author,
      "status" => status,
      "current_borrowing" => current_borrowing && borrowing_json(current_borrowing)
    }
    if recent_borrowings
      json["recent_borrowings"] = recent_borrowings.map { |borrowing| borrowing_json(borrowing) }
      json["borrowings_count"] = borrowings_count
    end
    json
  end

  def page_json(data, page: 1, per_page: 25, total: data.size)
    { "data" => data, "meta" => { "page" => page, "per_page" => per_page, "total" => total } }
  end

  def error_json(status, message, details = nil)
    { "error" => { "status" => status, "message" => message, "details" => details } }
  end
end

RSpec.configure do |config|
  config.include ApiJson, type: :request
end
