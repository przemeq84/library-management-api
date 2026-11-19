class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error(status: :not_found, message: "#{error.model || "Record"} not found")
  end

  rescue_from ActionController::ParameterMissing, ActionController::BadRequest,
              ActionDispatch::Http::Parameters::ParseError do |error|
    render_error(status: :bad_request, message: error.message)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error(status: :unprocessable_content, message: error.record.errors.full_messages.to_sentence,
                 details: error.record.errors.to_hash)
  end

  rescue_from Borrowing::Errors::Base do |error|
    render_error(status: :conflict, message: error.message)
  end

  private

  def render_error(status:, message:, details: nil)
    render status:, json: { error: { status:, message:, details: } }
  end
end
