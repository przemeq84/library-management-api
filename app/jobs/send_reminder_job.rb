# Sends one reminder for one borrowing, at most once.
#
# The `*_reminder_sent_at` column is claimed with a conditional UPDATE before sending, so a second run
# of this job (a duplicate enqueue or a Solid Queue retry after a crash) finds the claim taken and stops.
# A delivery error releases the claim and the job is retried; only a crash between claiming and
# sending can lose the reminder.
class SendReminderJob < ApplicationJob
  class DeliveryFailed < StandardError; end

  KINDS = %w[due_soon due_today].freeze

  retry_on DeliveryFailed, wait: :polynomially_longer, attempts: 5

  def perform(borrowing, kind)
    raise ArgumentError, "unknown reminder: #{kind.inspect}" unless KINDS.include?(kind)

    column = :"#{kind}_reminder_sent_at"
    return unless claim(borrowing, column)

    begin
      ReminderMailer.with(borrowing:).public_send(kind).deliver_now
    rescue StandardError => error
      Borrowing.where(id: borrowing.id).update_all(column => nil)
      raise DeliveryFailed, error.message
    end
  end

  private

  def claim(borrowing, column)
    Borrowing.active.with_reader_email.where(id: borrowing.id, column => nil).update_all(column => Time.current) == 1
  end
end
