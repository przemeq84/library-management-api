FactoryBot.define do
  factory :borrowing do
    book
    reader
    borrowed_at { Time.current }
    due_on { borrowed_at.to_date + Borrowing::DUE_AFTER }

    trait :returned do
      status { :returned }
      returned_at { borrowed_at + 7.days }
    end
  end
end
