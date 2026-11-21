# Demo data: video-game heroes borrowing classic literature. Idempotent, so `bin/rails db:seed`
# can run any number of times (it also runs on the first `docker compose up`).
#
# Borrowings are created relative to the day the seeds first run:
# - "Pride and Prejudice": returned by Mario, then borrowed by Lara Croft 27 days ago, so it's due
#   in 3 days (pending due-soon reminder) and shows a borrowing history.
# - "Moby-Dick": borrowed by Geralt of Rivia 30 days ago, so it's due today (pending due-today reminder).

readers = [
  { card_number: "100001", name: "Mario", email: "mario@example.com" },
  { card_number: "100002", name: "Lara Croft", email: "lara.croft@example.com" },
  { card_number: "100003", name: "Geralt of Rivia", email: "geralt@example.com" },
  { card_number: "100004", name: "Link", email: nil },
  { card_number: "100005", name: "Samus Aran", email: "samus@example.com" },
  { card_number: "100006", name: "Master Chief", email: nil }
].to_h do |attributes|
  [ attributes[:name], Reader.kept.find_or_create_by!(card_number: attributes[:card_number]) { _1.assign_attributes(attributes) } ]
end

books = [
  { serial_number: "200001", title: "Pride and Prejudice", author: "Jane Austen" },
  { serial_number: "200002", title: "Moby-Dick", author: "Herman Melville" },
  { serial_number: "200003", title: "Crime and Punishment", author: "Fyodor Dostoevsky" },
  { serial_number: "200004", title: "Don Quixote", author: "Miguel de Cervantes" },
  { serial_number: "200005", title: "Frankenstein", author: "Mary Shelley" },
  { serial_number: "200006", title: "Jane Eyre", author: "Charlotte Brontë" },
  { serial_number: "200007", title: "War and Peace", author: "Leo Tolstoy" },
  { serial_number: "200008", title: "The Odyssey", author: "Homer" }
].to_h do |attributes|
  [ attributes[:title], Book.kept.find_or_create_by!(serial_number: attributes[:serial_number]) { _1.assign_attributes(attributes) } ]
end

now = Time.current

pride_and_prejudice = books.fetch("Pride and Prejudice")
if pride_and_prejudice.borrowings.none?
  Borrowing.borrow!(book: pride_and_prejudice, reader: readers.fetch("Mario"), at: now - 50.days)
  Borrowing.return!(book: pride_and_prejudice, at: now - 30.days)
  Borrowing.borrow!(book: pride_and_prejudice, reader: readers.fetch("Lara Croft"), at: now - 27.days)
end

moby_dick = books.fetch("Moby-Dick")
if moby_dick.borrowings.none?
  Borrowing.borrow!(book: moby_dick, reader: readers.fetch("Geralt of Rivia"), at: now - Borrowing::DUE_AFTER)
end
