module Paginated
  DEFAULT_PER_PAGE = 25
  PER_PAGE_RANGE = 1..100
  # Largest OFFSET PostgreSQL accepts (bigint).
  MAX_OFFSET = 2**63 - 1

  # Plain digits only: no sign, spaces, underscores or decimals.
  # A module method, so including controllers can't call or override it.
  def self.parse_integer(value)
    value.to_i if value.is_a?(String) && value.match?(/\A[0-9]+\z/)
  end

  private

  def paginate(scope)
    page = page_param
    per_page = per_page_param
    raise ActionController::BadRequest, "page is out of range" if (page - 1) * per_page > MAX_OFFSET

    scope.paginate(page:, per_page:)
  end

  def page_param
    return 1 unless params.key?(:page)

    value = Paginated.parse_integer(params[:page])
    raise ActionController::BadRequest, "page must be a positive integer" unless value&.positive?

    value
  end

  def per_page_param
    return DEFAULT_PER_PAGE unless params.key?(:per_page)

    value = Paginated.parse_integer(params[:per_page])
    unless value && PER_PAGE_RANGE.cover?(value)
      raise ActionController::BadRequest,
            "per_page must be an integer between #{PER_PAGE_RANGE.min} and #{PER_PAGE_RANGE.max}"
    end

    value
  end
end
