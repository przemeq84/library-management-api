class Borrowing
  # Domain conflicts raised by borrowing rules; ApplicationController renders them as 409.
  module Errors
    class Base < StandardError; end

    class AlreadyBorrowed < Base
      def initialize(message = "Book is already borrowed")
        super
      end
    end

    class NotBorrowed < Base
      def initialize(message = "Book is not borrowed")
        super
      end
    end

    class BookStillBorrowed < Base
      def initialize(message = "Book is currently borrowed")
        super
      end
    end

    class ReaderHasActiveBorrowings < Base
      def initialize(message = "Reader has borrowed books that are not returned")
        super
      end
    end
  end
end
