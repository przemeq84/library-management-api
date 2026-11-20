class Borrowing
  # Storage for all config related to reminders
  class Reminder < Data.define(:name, :sent_at_column, :mailer_action, :due_in_days)
    DUE_SOON = new(name: "due_soon", sent_at_column: :due_soon_reminder_sent_at, mailer_action: :due_soon,
                   due_in_days: 1.day..REMIND_BEFORE)
    DUE_TODAY = new(name: "due_today", sent_at_column: :due_today_reminder_sent_at, mailer_action: :due_today,
                    due_in_days: -REMINDER_CATCH_UP..0.days)

    ALL = [ DUE_SOON, DUE_TODAY ].index_by(&:name).freeze

    def self.fetch(name)
      ALL.fetch(name.to_s)
    end

    def due_on_range(today)
      (today + due_in_days.begin)..(today + due_in_days.end)
    end
  end
end
