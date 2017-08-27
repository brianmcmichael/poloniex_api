# Poloniex API wrapper for Ruby 2.1.5+
# https://github.com/brianmcmichael/poloniex_api
# BTC: 1Azh1Sn3nzHE5RMnx8dQnJ4dkWAxFbUWEg

require 'poloniex/exceptions'

require 'logger'

LOGGER = Logger.new(STDOUT)

RETRY_DELAYS = [0, 2, 5, 30]

# Possible Commands
PUBLIC_COMMANDS = %w(returnTicker return24hVolume returnOrderBook marketTradeHist returnChartData returnCurrencies returnLoanOrders)

PRIVATE_COMMANDS = %w(returnBalances returnCompleteBalances returnDepositAddresses generateNewAddress returnDepositsWithdrawals returnOpenOrders returnTradeHistory returnAvailableAccountBalances returnTradableBalances returnOpenLoanOffers returnOrderTrades returnActiveLoans returnLendingHistory createLoanOffer cancelLoanOffer toggleAutoRenew buy sell cancelOrder moveOrder withdraw returnFeeInfo transferBalance returnMarginAccountSummary marginBuy marginSell getMarginPosition closeMarginPosition)

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
    self._nonce = "#{Time.now.to_f}".gsub('.', '')
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




  private

    # Increments the nonce
    def self.nonce
      self._nonce += 42
    end

end
