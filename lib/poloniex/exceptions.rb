module Poloniex
  # Exception for handling poloniex api errors
  class PoloniexError < StandardError; end

  # Exception for retry decorator
  class RetryException < PoloniexError; end

  # Exception when there's an issue with the request
  class RequestException < PoloniexError; end
end
