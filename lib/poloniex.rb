# Poloniex API wrapper for Ruby 2.1.5+
# https://github.com/brianmcmichael/poloniex_api
# BTC: 1Azh1Sn3nzHE5RMnx8dQnJ4dkWAxFbUWEg

require 'poloniex/exceptions'

require 'net/http'
require 'json'
require 'logger'
require 'uri'
require 'mime/types'
require 'openssl'
require 'Base64'

LOGGER = Logger.new(STDOUT)

RETRY_DELAYS = [0, 2, 5, 30]

# Possible Commands
PUBLIC_COMMANDS = %w(returnTicker return24hVolume returnOrderBook marketTradeHist returnChartData returnCurrencies returnLoanOrders)

PRIVATE_COMMANDS = %w(returnBalances returnCompleteBalances returnDepositAddresses generateNewAddress returnDepositsWithdrawals returnOpenOrders returnTradeHistory returnAvailableAccountBalances returnTradableBalances returnOpenLoanOffers returnOrderTrades returnActiveLoans returnLendingHistory createLoanOffer cancelLoanOffer toggleAutoRenew buy sell cancelOrder moveOrder withdraw returnFeeInfo transferBalance returnMarginAccountSummary marginBuy marginSell getMarginPosition closeMarginPosition)

POSITION_TYPES = %w(fillOrKill immediateOrCancel postOnly)

PUBLIC_API_BASE = 'https://poloniex.com/public?'
PRIVATE_API_BASE = 'https://poloniex.com/tradingApi'

UTF_8 = 'utf-8'
SHA512 = 'sha512'

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

  # FIXME make this a decorator
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

  # """ Main Api Function
  #   - encodes and sends <command> with optional [args] to Poloniex api
  #   - raises 'poloniex.PoloniexError' if an api key or secret is missing
  #     (and the command is 'private'), if the <command> is not valid, or
  #       if an error is returned from poloniex.com
  #   - returns decoded json api message """
  def self.call(command, args = {})
    # Get command type
    cmd_type = self.check_command(command)

    # Pass the command
    args['command'] = command
    payload = {}
    payload['timeout'] = self.timeout

    # private?
    if cmd_type == 'Private'
      payload['uri'] = PRIVATE_API_BASE

      # Set nonce
      args['nonce'] = self.nonce

      # Add args to payload
      payload['data'] = args

      # Sign data with secret key
      sign = OpenSSL::HMAC.digest(
          OpenSSL::HMAC.digest.new(SHA512),
          self.secret.encode(UTF_8),
          urlencode(args).encode(UTF_8)
      )

      # Add headers to payload
      payload['headers'] = {
          'Sign' => sign,
          'Key' => self.key
      }

      # Send the call
      # FIXME
      ret = _post(payload)

      # Return the data
      return self.handle_returned(ret.text)
    end
    if cmd_type == 'Public'

      # Encode URL
      payload['url'] = PUBLIC_API_BASE + URI.encode_www.form(args)

      # Send the call
      # FIXME
      ret = _get(payload['url'])

      return self.handle_returned(ret.text)
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
        out = JSON.parse(data)
      else
        out = JSON.parse(data, parse_float = self.json_nums, parse_int = self.json_nums)
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

  # PRIVATE COMMANDS

  # Returns all of your available balances.
  def self.return_balances
    self.call('returnBalances')
  end

  # Returns all of your balances, including available balance, balance
  #  on orders, and the estimated BTC value of your balance. By default,
  #  this call is limited to your exchange account; set the "account"
  #  parameter to "all" to include your margin and lending accounts.
  def self.return_complete_balances(account = 'all')
    return self.call('returnCompleteBalance', { 'account' => account.to_s })
  end

  # Returns all of your deposit addresses.
  def self.return_depost_addresses
    return self.call('returnDepositAddresses')
  end

  # Generates a new deposit address for the currency specified by the
  #   "currency" parameter.
  def self.generate_new_address(currency)
    return self.call('generateNewAddress', { 'currency' => currency })
  end

  # Returns your deposit and withdrawal history within a range,
  #  specified by the "_start" and "_end" parameters, both of which should be
  #  given as UNIX timestamps. (defaults to 1 month)
  def self.return_deposits_withdrawals(_start = false, _end = false)
    unless _start
      _start = time - self.MONTH
    end
    unless _end
      _end = time
    end
    args = {
        'start' => _start.to_s,
        'end' => _end.to_s
    }

    return self.call('returnDepositsWithdrawals', args)
  end

  # Returns your open orders for a given market, specified by the
  #  "currencyPair" parameter, e.g. "BTC_XCP". Set "currencyPair" to
  #  "all" to return open orders for all markets.
  def self.return_open_orders(currency_pair = 'all')
    return self.call('returnOpenOrders', currency_pair.to_s.upcase)
  end

  #Returns your trade history for a given market, specified by the
  #  "currencyPair" parameter. You may specify "all" as the currencyPair to
  #  receive your trade history for all markets. You may optionally specify
  #  a range via "start" and/or "end" POST parameters, given in UNIX
  #  timestamp format; if you do not specify a range, it will be limited to
  #  one day.
  def self.return_trade_history(currency_pair = 'all', _start = false, _end = false)
    args = { 'currencyPair' => currency_pair.to_s.upcase }
    if _start
      args['start'] = _start
    end
    if _end
      args['end'] = _end
    end
    return self.call('returnTradeHistory', args)
  end

  # Returns all trades involving a given order, specified by the
  #  "orderNumber" parameter. If no trades for the order have occurred
  #  or you specify an order that does not belong to you, you will receive
  #  an error.
  def self.return_order_trades(order_number)
    return self.call('returnOrderTrades', { 'orderNumber' => order_number.to_s })
  end

  # Places a limit buy order in a given market. Required parameters are
  #  "currencyPair", "rate", and "amount". You may optionally set "orderType"
  #  to "fillOrKill", "immediateOrCancel" or "postOnly". A fill-or-kill order
  #  will either fill in its entirety or be completely aborted. An
  #  immediate-or-cancel order can be partially or completely filled, but
  #  any portion of the order that cannot be filled immediately will be
  #  canceled rather than left on the order book. A post-only order will
  #  only be placed if no portion of it fills immediately; this guarantees
  #  you will never pay the taker fee on any part of the order that fills.
  #      If successful, the method will return the order number.
  def self.buy(currency_pair, rate, amount, order_type = false)
    args = {
        'currencyPair' => currency_pair.to_s.upcase,
        'rate' => rate.to_s,
        'amount' => amount.to_s
    }
    # Order type specified?
    if order_type
      # Check type
      unless POSITION_TYPES.include? order_type
        raise PoloniexError('Invalid order type.')
      end
      args[order_type] = 1
    end
    return self.call('buy', args)
  end

  # Places a sell order in a given market. Parameters and output are
  #  the same as for the buy method.
  def self.sell(currency_pair, rate, amount, order_type = false)
    args = {
        'currencyPair' => currency_pair.to_s.upcase,
        'rate' => rate.to_s,
        'amount' => amount.to_s
    }
    # Order type specified?
    if order_type
      unless POSITION_TYPES.include? order_type
        raise PoloniexError('Invalid order type.')
      end
      args[order_type] = 1
    end

    return self.call('sell', args)
  end

  # Cancels an order you have placed in a given market. Required
  #  parameter is "order_number".
  def self.cancel_order(order_number)
    return self.call('cancelOrder', { 'orderNumber' => order_number.to_s })
  end

  # Cancels an order and places a new one of the same type in a single
  #    atomic transaction, meaning either both operations will succeed or both
  #    will fail. Required parameters are "orderNumber" and "rate"; you may
  #    optionally specify "amount" if you wish to change the amount of the new
  #    order. "postOnly" or "immediateOrCancel" may be specified as the
  #    "orderType" param for exchange orders, but will have no effect on
  #    margin orders.
  def self.move_order(order_number, rate, amount = false, order_type = false )
    args = {
        'orderNumber' => order_number.to_s,
        'rate' => rate.to_s
    }
    if amount
      args['amount'] = amount.to_s
    end

    # Order type specified?
    if order_type
      unless POSITION_TYPES[1,2].include? order_type
        raise PoloniexError("Invalid order type #{order_type.to_s}")
      end
      args[order_type] = 1
    end

    return self.call('moveOrder', args)
  end

  # Immediately places a withdrawal for a given currency, with no email
  #  confirmation. In order to use this method, the withdrawal privilege
  #  must be enabled for your API key. Required parameters are
  #  "currency", "amount", and "address". For XMR withdrawals, you may
  # optionally specify "paymentId".
  def self.withdraw(currency, amount, address, payment_id = false)
    args = {
        'currency' => currency.to_s.upcase,
        'amount' => amount.to_s,
        'address' => address.to_s
    }

    if payment_id
      args['paymentId'] = payment_id.to_s
    end

    return self.call('withdraw', args)
  end

  # If you are enrolled in the maker-taker fee schedule, returns your
  #  current trading fees and trailing 30-day volume in BTC. This
  #  information is updated once every 24 hours.
  def self.return_fee_info
    return self.call('returnFeeInfo')
  end

  # Returns your balances sorted by account. You may optionally specify
  #  the "account" parameter if you wish to fetch only the balances of
  #  one account. Please note that balances in your margin account may not
  #  be accessible if you have any open margin positions or orders.
  def self.return_available_account_balances(account = false)
    if account
      return self.call('returnAvailableAccountBalances', { 'account' => account })
    else
      return self.call('returnAvailableAccountBalances')
    end
  end

  # Returns your current tradable balances for each currency in each
  #  market for which margin trading is enabled. Please note that these
  #  balances may vary continually with market conditions.
  def self.return_tradable_balances
    return self.call('returnTradeableBalances')
  end

  # Transfers funds from one account to another (e.g. from your
  #  exchange account to your margin account). Required parameters are
  #  "currency", "amount", "fromAccount", and "toAccount"
  def self.transfer_balance(currency, amount, from_account, to_account, confirmed = false)
    args = {
        'currency' => currency.to_s.upcase,
        'amount' => amount.to_s,
        'fromAccount' => from_account.to_s,
        'toAccount' => to_account.to_s
    }
    if confirmed
      args['confirmed'] = 1
    end

    return self.call('transferBalance', args)
  end

  # Returns a summary of your entire margin account. This is the same
  #  information you will find in the Margin Account section of the Margin
  #  Trading page, under the Markets list
  def self.return_margin_account_summary
    return self.call('returnMarginAccountSummary')
  end

  # Places a margin buy order in a given market. Required parameters are
  #  "currencyPair", "rate", and "amount". You may optionally specify a
  #  maximum lending rate using the "lendingRate" parameter (defaults to 2).
  #  If successful, the method will return the order number and any trades
  #  immediately resulting from your order.
  def self.margin_buy(currency_pair, rate, amount, lending_rate = 2)
    args = {
        'currencyPair' => currency_pair.to_s.upcase,
        'rate' => rate.to_s,
        'amount' => amount.to_s,
        'lendingRate' => lending_rate.to_s
    }
    return self.call('marginBuy', args)
  end

  # Places a margin sell order in a given market. Parameters and output
  #  are the same as for the marginBuy method.
  def self.margin_sell(currency_pair, rate, amount, lending_rate = 2)
    args = {
        'currencyPair' => currency_pair.to_s.upcase,
        'rate' => rate.to_s,
        'amount' => amount.to_s,
        'lendingRate' => lending_rate.to_s
    }
    self.call('marginSell', args)
  end

  # Returns information about your margin position in a given market,
  #  specified by the "currencyPair" parameter. You may set
  #  "currencyPair" to "all" if you wish to fetch all of your margin
  #  positions at once. If you have no margin position in the specified
  #  market, "type" will be set to "none". "liquidationPrice" is an
  #  estimate, and does not necessarily represent the price at which an
  #  actual forced liquidation will occur. If you have no liquidation price,
  #  the value will be -1. (defaults to 'all')
  def self.get_margin_position(currency_pair = 'all')
    args = {
        'currencyPair' => currency_pair.to_s.upcase
    }
    return self.call('getMarginPosition', args)
  end

  # Closes your margin position in a given market (specified by the
  #  "currencyPair" parameter) using a market order. This call will also
  #  return success if you do not have an open position in the specified
  #  market.
  def self.close_margin_position(currency_pair)
    args = {
        'currencyPair' => currency_pair.to_s_upcase
    }
    return self.call('currencyPair', args)
  end

  # Creates a loan offer for a given currency. Required parameters are
  #  "currency", "amount", "lendingRate", "duration" (num of days, defaults
  #  to 2), "autoRenew" (0 or 1, defaults to 0 'off').
  def self.create_loan_offer(currency, amount, lending_rate, auto_renew = 0, duration = 2)
    args = {
        'currency' => currency.to_s.upcase,
        'amount' => amount.to_s,
        'duration' => duration.to_s,
        'autoRenew' => auto_renew.to_s,
        'lendingRate' => lending_rate.to_s
    }
    return self.call('createLoanOffer', args)
  end

  # Cancels a loan offer specified by the "orderNumber" parameter.
  def self.cancel_loan_offer(order_number)
    args = {
        'orderNumber' => order_number.to_s
    }
    return self.call('cancelLoanOffer', args)
  end

  # Returns your open loan offers for each currency.
  def self.return_open_loan_offers
    return self.call('returnOpenLoanOffers')
  end

  # Returns your active loans for each currency.
  def self.return_active_loans
    return self.call('returnActiveLoans')
  end

  # Returns your lending history within a time range specified by the
  #  "start" and "end" parameters as UNIX timestamps. "limit" may also
  #  be specified to limit the number of rows returned. (defaults to the last
  #  months history)
  def self.return_lending_history(_start = false, _end = false, limit = false)
    unless _start
      _start = time - self.MONTH
    end
    unless _end
      _end = time
    end
    args = {
        'start' => _start.to_s,
        'end' => _end.to_s
    }
    if limit
      args['limit'] = limit.to_s
    end
    return self.call('returnLendingHistory', args)
  end

  # Toggles the autoRenew setting on an active loan, specified by the
  #  "orderNumber" parameter. If successful, "message" will indicate
  #  the new autoRenew setting.
  def self.toggle_auto_renew(order_number)
    args = {
        'orderNumber' => order_number.to_s
    }
    self.call('toggleAutoRenew', args)
  end

  private

    # Increments the nonce
    def self.nonce
      self._nonce += 42
    end

    # Gets the current time as float
    #   example: 1503853685.5080986
    def time
      Time.now.to_f
    end

    # TODO utilize path and port
    def _get(uri, path = nil, port = nil)
      address = URI.parse(uri)
      Net::HTTP.get_response(address)
    end

    # TODO map more closely to canonical post
    def _post(url, data = {}, initheader = nil, dest = nil)
      address = URI.parse(url)
      Net::HTTP.post_form(address, data)
    end

end
