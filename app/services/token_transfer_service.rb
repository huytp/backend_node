require 'eth'
require 'digest/keccak'
require_relative 'rpc_client_service'

class TokenTransferService
  POLYGON_AMOY_CHAIN_ID = 80_002
  DEFAULT_GAS_LIMIT = 100_000
  TOKEN_DECIMALS = 18

  def initialize
    @rpc = RpcClientService.new
    @token_address = ENV['DEVPN_TOKEN_ADDRESS']
    @reward_wallet_private_key = ENV['REWARD_WALLET_PRIVATE_KEY']

    raise "Missing DEVPN_TOKEN_ADDRESS" unless @token_address
    raise "Missing REWARD_WALLET_PRIVATE_KEY" unless @reward_wallet_private_key

    # Initialize reward wallet key
    private_key = @reward_wallet_private_key.to_s
    private_key = private_key[2..-1] if private_key.start_with?('0x')
    @reward_wallet_key = Eth::Key.new(priv: private_key)
  end

  # Transfer tokens from reward wallet to node
  # @param node_address [String] Address of the node to receive tokens
  # @param amount [Integer, Float] Amount in DEVPN tokens (will be converted to wei)
  def transfer_to_node(node_address, amount)
    # Convert amount to wei (always treat input as DEVPN tokens, not wei)
    # If amount is very large (> 10^15), assume it's already in wei
    if amount.to_i > 10**15
      # Already in wei format
      amount_wei = amount.to_i
      Rails.logger.warn("⚠️  Large amount detected, treating as wei: #{amount_wei}")
    else
      # Treat as DEVPN tokens and convert to wei
      amount_wei = (amount.to_f * 10**TOKEN_DECIMALS).to_i
    end

    Rails.logger.info("=" * 60)
    Rails.logger.info("💸 Transferring DEVPN Tokens")
    Rails.logger.info("=" * 60)
    Rails.logger.info("From: #{@reward_wallet_key.address}")
    Rails.logger.info("To: #{node_address}")
    Rails.logger.info("Amount: #{amount_wei / 10**TOKEN_DECIMALS.to_f} DEVPN (#{amount_wei} wei)")
    Rails.logger.info("=" * 60)

    # Check balance before transfer
    Rails.logger.info("💰 Checking balances before transfer...")
    from_balance = get_token_balance(@reward_wallet_key.address.to_s)
    from_balance_formatted = from_balance.to_f / 10**TOKEN_DECIMALS
    Rails.logger.info("   From balance: #{from_balance_formatted} DEVPN")

    if from_balance < amount_wei
      error_msg = "❌ Insufficient balance! Need #{amount_wei / 10**TOKEN_DECIMALS.to_f} DEVPN, but only have #{from_balance_formatted} DEVPN"
      Rails.logger.error(error_msg)
      raise error_msg
    end

    # Function selector: transfer(address,uint256)
    function_sig = "transfer(address,uint256)"
    hash = keccak256(function_sig)
    selector = "0x" + hash[0..7]

    # Encode parameters
    encoded_address = encode_address(node_address)
    encoded_amount = encode_uint256(amount_wei)

    function_data = "#{selector}#{encoded_address}#{encoded_amount}"

    # Get transaction parameters
    Rails.logger.info("📝 Getting transaction parameters...")
    nonce_hex = @rpc.eth_get_transaction_count(@reward_wallet_key.address.to_s, 'latest')
    nonce = @rpc.hex_to_int(nonce_hex)
    Rails.logger.info("   Nonce: #{nonce}")

    gas_price_hex = @rpc.eth_gas_price
    gas_price = @rpc.hex_to_int(gas_price_hex)
    gas_price = 30_000_000_000 if gas_price == 0
    Rails.logger.info("   Gas Price: #{gas_price} wei (#{gas_price / 1_000_000_000.0} gwei)")

    # Estimate gas
    Rails.logger.info("   Estimating gas...")
    begin
      gas_limit_hex = @rpc.eth_estimate_gas({
        from: @reward_wallet_key.address.to_s,
        to: @token_address,
        data: function_data
      })
      gas_limit = @rpc.hex_to_int(gas_limit_hex)
      gas_limit = (gas_limit * 1.2).to_i
      Rails.logger.info("   Estimated Gas Limit: #{gas_limit}")
    rescue => e
      Rails.logger.warn("   ⚠️  Gas estimation failed: #{e.message}, using default")
      gas_limit = DEFAULT_GAS_LIMIT
    end

    # Build transaction
    Rails.logger.info("📝 Building transaction...")
    transaction = Eth::Tx.new(
      chain_id: POLYGON_AMOY_CHAIN_ID,
      nonce: nonce,
      gas_price: gas_price,
      gas_limit: gas_limit,
      to: @token_address,
      data: function_data[2..-1] # Remove 0x prefix
    )

    # Sign transaction
    Rails.logger.info("✍️  Signing transaction...")
    transaction.sign(@reward_wallet_key)
    signed_tx = transaction.hex
    signed_tx = "0x#{signed_tx}" unless signed_tx.start_with?('0x')

    # Send transaction
    Rails.logger.info("📤 Sending transaction...")
    tx_hash = @rpc.eth_send_raw_transaction(signed_tx)
    Rails.logger.info("✅ Transaction sent!")
    Rails.logger.info("📋 Transaction Hash: #{tx_hash}")
    Rails.logger.info("🔗 View on explorer: https://amoy.polygonscan.com/tx/#{tx_hash}")

    # Wait for receipt
    Rails.logger.info("⏳ Waiting for confirmation...")
    receipt = wait_for_receipt(tx_hash, 120)

    if receipt && receipt['status'] == '0x1'
      gas_used = @rpc.hex_to_int(receipt['gasUsed'])
      Rails.logger.info("✅ Transfer successful!")
      Rails.logger.info("📊 Block: #{receipt['blockNumber']}")
      Rails.logger.info("⛽ Gas used: #{gas_used}")

      # Check final balances
      Rails.logger.info("💰 Final balances:")
      from_balance_after = get_token_balance(@reward_wallet_key.address.to_s)
      to_balance_after = get_token_balance(node_address)

      Rails.logger.info("   From: #{from_balance_after.to_f / 10**TOKEN_DECIMALS} DEVPN")
      Rails.logger.info("   To: #{to_balance_after.to_f / 10**TOKEN_DECIMALS} DEVPN")

      return {
        success: true,
        tx_hash: tx_hash,
        receipt: receipt,
        from_balance_before: from_balance,
        from_balance_after: from_balance_after,
        to_balance_after: to_balance_after
      }
    else
      Rails.logger.error("❌ Transfer failed!")
      if receipt
        Rails.logger.error("   Status: #{receipt['status']}")
      end
      return { success: false, tx_hash: tx_hash, receipt: receipt }
    end
  rescue => e
    Rails.logger.error("❌ Error: #{e.message}")
    Rails.logger.error(e.backtrace.first(5))
    { success: false, error: e.message }
  end

  # Get reward wallet balance
  # @return [Integer] Balance in wei
  def get_reward_wallet_balance
    balance = get_token_balance(@reward_wallet_key.address.to_s)
    Rails.logger.info("Reward wallet balance: #{balance.to_f / 10**TOKEN_DECIMALS} DEVPN")
    balance
  end

  # Get node balance
  # @param node_address [String] Address of the node
  # @return [Integer] Balance in wei
  def get_node_balance(node_address)
    balance = get_token_balance(node_address)
    Rails.logger.info("Node balance (#{node_address}): #{balance.to_f / 10**TOKEN_DECIMALS} DEVPN")
    balance
  end

  private

  # Get token balance for an address
  # @param address [String] Wallet address
  # @return [Integer] Balance in wei
  def get_token_balance(address)
    # Function: balanceOf(address)
    function_sig = "balanceOf(address)"
    hash = keccak256(function_sig)
    selector = "0x" + hash[0..7]

    encoded_addr = encode_address(address)
    function_data = "#{selector}#{encoded_addr}"

    result = @rpc.eth_call(@token_address, function_data)
    hex_to_int(result)
  end

  # Convert hex string to integer (handles nil and various formats)
  # @param hex_value [String, nil] Hex value to convert
  # @return [Integer] Integer value
  def hex_to_int(hex_value)
    return 0 if hex_value.nil?
    hex_str = hex_value.to_s
    hex_str = hex_str.start_with?('0x') ? hex_str : "0x#{hex_str}"
    hex_str.to_i(16)
  rescue => e
    Rails.logger.warn("⚠️  Error converting hex to int: #{e.message}, value: #{hex_value.inspect}")
    0
  end

  # Generate Keccak-256 hash
  # @param data [String] Data to hash
  # @return [String] Hex hash
  def keccak256(data)
    Digest::Keccak.hexdigest(data, 256)
  end

  # Encode Ethereum address to 64-character hex string (padded)
  # @param address [String] Ethereum address
  # @return [String] Encoded address (64 chars, lowercase, zero-padded)
  def encode_address(address)
    addr = address.to_s
    addr = addr[2..-1] if addr.start_with?('0x')
    addr.downcase.rjust(64, '0')
  end

  # Encode uint256 value to 64-character hex string (padded)
  # @param value [Integer] Value to encode
  # @return [String] Encoded value (64 chars, zero-padded)
  def encode_uint256(value)
    value.to_i.to_s(16).rjust(64, '0')
  end

  # Wait for transaction receipt with timeout
  # @param tx_hash [String] Transaction hash
  # @param max_wait [Integer] Maximum wait time in seconds
  # @return [Hash, nil] Transaction receipt or nil if timeout
  def wait_for_receipt(tx_hash, max_wait = 120)
    start_time = Time.now
    while Time.now - start_time < max_wait
      sleep 2
      receipt = @rpc.eth_get_transaction_receipt(tx_hash)
      return receipt if receipt && receipt['blockNumber']
    end
    Rails.logger.warn("⚠️  Transaction receipt not found after #{max_wait}s")
    nil
  end
end

