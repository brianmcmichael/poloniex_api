# Poloniex API wrapper for Ruby 2.1.5+
# https://github.com/brianmcmichael/poloniex_api
# BTC: 1Azh1Sn3nzHE5RMnx8dQnJ4dkWAxFbUWEg

require 'poloniex/exceptions'

require 'logger'
require 'uri'

LOGGER = Logger.new(STDOUT)

RETRY_DELAYS = [0, 2, 5, 30]

# Possible Commands
PUBLIC_COMMANDS = %w(returnTicker return24hVolume returnOrderBook marketTradeHist returnChartData returnCurrencies returnLoanOrders)

PRIVATE_COMMANDS = %w(returnBalances returnCompleteBalances returnDepositAddresses generateNewAddress returnDepositsWithdrawals returnOpenOrders returnTradeHistory returnAvailableAccountBalances returnTradableBalances returnOpenLoanOffers returnOrderTrades returnActiveLoans returnLendingHistory createLoanOffer cancelLoanOffer toggleAutoRenew buy sell cancelOrder moveOrder withdraw returnFeeInfo transferBalance returnMarginAccountSummary marginBuy marginSell getMarginPosition closeMarginPosition)

PUBLIC_API_BASE = 'https://poloniex.com/public?'

# The Poloniex Object
class Poloniex

  # @param [String] key api key supplied by Poloniex
  # @param [String] secret hash supplied by Poloniex
  # @param [int] timeout time in sec to wait for an api response
  #   (otherwise 'requests.exceptions.Timeout' is raised)
  # @param [datatype] json_nums to use when parsing json ints and floats
  def initialize(key = false, secret = false, timeout = nil, json_nums = false)
    self.logger = LOGGER

    # create nonce
    self._nonce = "#{time}".gsub('.', '')
    self.json_nums = json_nums
    self.key = key
    self.secret = secret
    self.timeout = timeout

    # Time Placeholders: (MONTH == 30*DAYS)
    # self.MINUTE, self.HOUR, self.DAY, self.WEEK, self.MONTH, self.YEAR
    self.MINUTE = 60
    self.HOUR = self.MINUTE * 60
    self.DAY = self.HOUR * 24
    self.WEEK = self.DAY * 7
    self.MONTH = self.DAY * 30
    self.YEAR = self.DAY * 365
  end

  def retry(func)
  end

  def retrying(*args, **kwargs)
    problems = []
    RETRY_DELAYS.each do |delay|
      begin
        # attempt call
        return func(*args, **kwargs)
      rescue RequestException => problem
        problems.push problem
        if delay == RETRY_DELAYS.last
          raise RetryException "Retry delays exhausted #{problem}"
        end
      end
      if problems.any?
        LOGGER.debug problems.join("\n")
      end
    end
  end

  # Returns if the command is private of public, raises PoloniexError
  #   if command is not found
  def self.check_command(command)
    if PRIVATE_COMMANDS.include? command
      # Check for keys
      unless self.key && self.secret
        raise PoloniexError "An API key and Secret Key are required!"
      end
      return "Private"
    end
    if PUBLIC_COMMANDS.include? command
      return 'Public'
    end
    raise PoloniexError "Invalid command: #{command}"
  end

  # Handles the returned data from Poloniex
  def self.handle_returned(data)
    begin
      unless self.json_nums
        out = loads(data)
      else
        out = loads(data, parse_float = self.json_nums, parse_int = self.json_nums)
      end
    rescue
      self.logger.error(data)
      raise PoloniexError "Invalid json response returned!"
    end

    if out.include? 'error'

      # update nonce if we fell behind
      if out['error'].include? "Nonce must be greater"
        self._nonce = int(out['error'].split('.')[0].split()[-1])
        # raise RequestException so we try again
        raise RequestException("PoloniexError #{out['error']}")
      end

      if out['error'].downcase.include? "please try again"
        # Raise RequestException so we try again
        raise RequestException("PoloniexError #{out['error']}")
      end

      raise PoloniexError(out['error'])
    end
    return out
  end

  # PUBLIC COMMANDS

  # Returns the ticker for all markets
  def self.return_ticker
    return self.call('returnTicker')
  end

  # Returns the 24-hour volume for all markets, plus totals for primary currencies.
  def self.return_24h_volume
    return self.call('return24hVolume')
  end

  # Returns the order book for a given market as well as a sequence
  #   number for use with the Push API and an indicator specifying whether the
  #   market is frozen. (defaults to 'all' markets, at a 'depth' of 20 orders)
  def self.return_order_book(currency_pair='all', depth=20)
    return self.call('returnOrderBook', { currency_pair: str(currency_pair).upcase, depth: depth.to_s })
  end

  # Returns the past 200 trades for a given market, or up to 50,000
  # trades between a range specified in UNIX timestamps by the "start" and
  # "end" parameters.
  # TODO Add retry decorator
  def self.market_trade_hist(currency_pair, _start: false, _end: false)
    args =  { "command" => 'returnTradeHistory', "currencyPair" => currency_pair.to_s.upcase }
    if _start
      args['start'] = _start
    end
    if _end
      args['end'] = _end
    end
    url = URI.parse(PUBLIC_API_BASE)
    url.query = URI.encode_www_form(args)
    ret = _get(url.to_s, timeout: self.timeout)

    self.handle_returned(ret.text)
  end

  # Returns candlestick chart data. Parameters are "currencyPair",
  #  "period" (candlestick period in seconds; valid values are 300, 900,
  #  1800, 7200, 14400, and 86400), "_start", and "_end". "Start" and "end"
  #  are given in UNIX timestamp format and used to specify the date range
  #  for the data returned (default date range is _start='1 day ago' to
  #  _end='now')
  def self.return_chart_data(currency_pair, period: false, _start: false, _end: false)
    unless [300, 900, 1800, 7200, 14400, 86400].include? period
      raise PoloniexError("#{period.to_s} invalid candle period")
    end

    unless _start
      _start = time - self.DAY
    end
    unless _end
      _end = time
    end
    self.call('returnChartData', {
        'currencyPair' => currencyPair.to_s.upcase,
        'period' => period.to_s,
        '_start' => _start.to_s,
        '_end' => _end.to_s })
  end

  # Returns information about all currencies.
  def self.return_currencies
    self.call('returnCurrencies')
  end

  # Returns the list of loan offers and demands for a given currency,
  #  specified by the "currency" parameter
  def self.return_loan_orders(currency)
    self.call('returnLoanOrders', {
        'currency' => currency.to_s.upcase
    })
  end
  
  private

    # Increments the nonce
    def self.nonce
      self._nonce += 42
    end

    def time
      Time.now.to_f
    end

end
