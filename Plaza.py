import web3
import requests
import asyncio
import random
import json
import os
from datetime import datetime
from colorama import Fore, Style, init
from decimal import Decimal
from eth_account import Account

# Initialize colorama for colored logging
init(autoreset=True)

def display_header():
    custom_ascii_art = f"""
    {Fore.CYAN}
    █████╗ ██╗██████╗ ██████╗ ██████╗  ██████╗ ██████╗ 
    ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔═══██╗██╔══██╗
    ███████║██║██████╔╝██║  ██║██████╔╝██║   ██║██████╔╝
    ██╔══██║██║██╔══██╗██║  ██║██╔══██╗██║   ██║██╔═══╝ 
    ██║  ██║██║██║  ██║██████╔╝██║  ██║╚██████╔╝██║     
    ╚═╝  ╚═╝╚═╝╚═╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     
                                                        
    ██╗███╗   ██╗███████╗██╗██████╗ ███████╗██████╗     
    ██║████╗  ██║██╔════╝██║██╔══██╗██╔════╝██╔══██╗    
    ██║██╔██╗ ██║███████╗██║██║  ██║█████╗  ██████╔╝    
    ██║██║╚██╗██║╚════██║██║██║  ██║██╔══╝  ██╔══██╗    
    ██║██║ ╚████║███████║██║██████╔╝███████╗██║  ██║    
    ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝    {Fore.RESET}
    """
    print(custom_ascii_art)
    print(f"{Fore.YELLOW}PLAZA FINANCE AUTO BOT")
    print("Telegram : t.me/AirdropInsiderID", Fore.RESET)
    print("=================================================")
    print("")

display_header()

# Initialize web3 with Sepolia Base RPC URL
w3 = web3.Web3(web3.HTTPProvider('https://sepolia.base.org'))

# Konversi alamat menjadi checksum address
WSTETH_ADDRESS = w3.to_checksum_address('0x13e5fb0b6534bb22cbc59fae339dbbe0dc906871')
CONTRACT_ADDRESS = w3.to_checksum_address('0x47129e886b44B5b8815e6471FCD7b31515d83242')

# Contract ABI for bondToken, lToken, create, and redeem functions
CONTRACT_ABI = [
    {"inputs":[],"name":"bondToken","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"lToken","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"inputs":[{"internalType":"enum Pool.TokenType","name":"tokenType","type":"uint8"},{"internalType":"uint256","name":"depositAmount","type":"uint256"},{"internalType":"uint256","name":"minAmount","type":"uint256"}],"name":"create","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"enum Pool.TokenType","name":"tokenType","type":"uint8"},{"internalType":"uint256","name":"depositAmount","type":"uint256"},{"internalType":"uint256","name":"minAmount","type":"uint256"}],"name":"redeem","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}
]

# ERC-20 ABI for allowance, approve, and balanceOf
ERC20_ABI = [
    {"constant":True,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"type":"function"},
    {"constant":False,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"type":"function"},
    {"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"}
]

async def ensure_unlimited_spending(private_key, spender_address):
    """Ensure unlimited spending for wstETH"""
    account = w3.eth.account.from_key(private_key)
    owner_address = account.address

    # Create contract instance for wstETH
    wsteth_contract = w3.eth.contract(address=WSTETH_ADDRESS, abi=ERC20_ABI)

    try:
        # Check the current allowance
        allowance = wsteth_contract.functions.allowance(owner_address, spender_address).call()
        max_uint = int('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', 16)

        if allowance < max_uint:
            print(Fore.YELLOW + f"Allowance for wstETH not unlimited. Setting to unlimited")

            # Approve unlimited spending
            approve_txn = wsteth_contract.functions.approve(spender_address, max_uint)
            gas_estimate = approve_txn.estimate_gas({'from': owner_address})
            nonce = w3.eth.get_transaction_count(owner_address)

            # Build and sign the transaction
            transaction = approve_txn.build_transaction({
                'from': owner_address,
                'gas': gas_estimate,
                'nonce': nonce,
                'gasPrice': w3.eth.gas_price,
                'chainId': w3.eth.chain_id  # Add chainId explicitly
            })
            signed_txn = w3.eth.account.sign_transaction(transaction, private_key)

            # Send the transaction
            tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)  # Perbaikan di sini
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

            print(Fore.GREEN + f"Unlimited allowance set for wstETH with tx hash: {tx_hash.hex()}")
        else:
            print(Fore.GREEN + "Allowance for wstETH is already unlimited")

    except Exception as error:
        print(Fore.RED + f"Error setting unlimited allowance for wstETH: {error}")
        import traceback
        traceback.print_exc()
        
async def claim_faucet(address):
    """Claim faucet tokens"""
    try:
        response = requests.post(
            'https://api.plaza.finance/faucet/queue', 
            json={'address': address},
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Content-Type': 'application/json',
                'x-plaza-api-key': 'bfc7b70e-66ad-4524-9bb6-733716c4da94',
            }
        )
        
        print(Fore.GREEN + f"Faucet claim initiated successfully for {address}")
        print(Fore.YELLOW + f"Claim Response: {response.json()}")
    
    except requests.exceptions.HTTPError as error:
        if error.response.status_code == 429:
            print(Fore.RED + "You can only use the faucet once per day.")
        elif error.response.status_code == 403:
            print(Fore.RED + "403 Forbidden: You may have hit a rate limit or are blocked.")
        else:
            print(Fore.RED + f"Error claiming faucet: {error}")

def get_random_deposit_amount():
    """Generate random deposit amount between 0.009 and 0.01 ETH"""
    min_amount, max_amount = 0.009, 0.01
    random_eth_amount = random.uniform(min_amount, max_amount)
    return w3.to_wei(random_eth_amount, 'ether')

async def get_fifty_percent_balance(token_type, user_address):
    """Get 50% of the token balance"""
    token_contract_address = await get_token_contract_address(token_type)
    token_contract = w3.eth.contract(address=token_contract_address, abi=ERC20_ABI)
    balance = token_contract.functions.balanceOf(user_address).call()

    # Return half of the balance in Wei
    return balance // 2

async def get_token_contract_address(token_type):
    """Get token contract address based on token type"""
    contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)
    
    if token_type == 0:
        return contract.functions.bondToken().call()
    elif token_type == 1:
        return contract.functions.lToken().call()

async def perform_action(action, token_type, deposit_amount, min_amount, private_key):
    """Perform create or redeem action with retry mechanism"""
    max_retries = 5
    retry_delay = 30  # seconds

    account = w3.eth.account.from_key(private_key)
    sender_address = account.address
    contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=CONTRACT_ABI)

    for attempt in range(max_retries):
        try:
            token_name = "Bond" if token_type == 0 else "Leverage"

            if action == 'create':
                action_method = contract.functions.create(token_type, deposit_amount, min_amount)
            elif action == 'redeem':
                redeem_amount = await get_fifty_percent_balance(token_type, sender_address)

                if redeem_amount == 0:
                    print(Fore.RED + "No balance to redeem.")
                    return

                action_method = contract.functions.redeem(token_type, redeem_amount, min_amount)
            else:
                raise ValueError('Invalid action. Use "create" or "redeem".')

            # Estimate gas and get nonce
            nonce = w3.eth.get_transaction_count(sender_address)
            gas_estimate = action_method.estimate_gas({'from': sender_address})

            # Build transaction
            transaction = action_method.build_transaction({
                'from': sender_address,
                'gas': gas_estimate,
                'nonce': nonce,
            })

            # Sign transaction
            signed_txn = w3.eth.account.sign_transaction(transaction, private_key)

            try:
                # Send transaction
                tx_hash = w3.eth.send_raw_transaction(signed_txn.raw_transaction)  # Perbaikan di sini
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
                print(Fore.GREEN + f"TX success hash: {tx_hash.hex()}")
                return
            except Exception as tx_error:
                print(Fore.RED + f'Transaction failed: {tx_error}')

        except Exception as error:
            print(Fore.RED + f"Error performing {action} on attempt {attempt + 1}: {error}")

            if attempt < max_retries - 1:
                print(Fore.YELLOW + f"Retrying in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)
            else:
                print(Fore.RED + f"Max retries reached. Failed to perform {action}.")

def read_private_keys():
    """Read private keys from private_keys.txt"""
    try:
        with open('private_keys.txt', 'r') as file:
            keys = [key.strip() for key in file if key.strip()]

        # Validate private key length
        for index, key in enumerate(keys, 1):
            if len(key) != 64:
                raise ValueError(f"Private key at line {index} must be 32 bytes (64 characters) long")

        return keys
    
    except Exception as error:
        print(Fore.RED + f'Error reading private_keys.txt: {error}')
        exit(1)

async def process_wallets():
    """Process wallets in a cycle"""
    BOND_TOKEN_TYPE = 0  # 0 for Bond ETH
    LEVERAGE_TOKEN_TYPE = 1  # 1 for Leverage ETH
    MIN_AMOUNT = w3.to_wei('0.01', 'ether')

    
    private_keys = read_private_keys()

    for private_key in private_keys:
        account = w3.eth.account.from_key(private_key)
        wallet_address = account.address

        print(Fore.YELLOW + f"\n=== CYCLE STARTED FOR WALLET: {Fore.BLUE + wallet_address} ===")
        
        # Step 1: Claim the faucet
        print(Fore.GREEN + f"Claiming faucet for {wallet_address}...")
        await claim_faucet(wallet_address)

        # Step 2: Ensure unlimited spending for wstETH
        await ensure_unlimited_spending(private_key, CONTRACT_ADDRESS)

        # Step 3: Create Bond Token with random deposit amount
        random_bond_amount = get_random_deposit_amount()
        print(Fore.BLUE + f"Creating Bond Token with amount: {Fore.YELLOW + str(w3.from_wei(random_bond_amount, 'ether'))} BOND")
        await perform_action('create', BOND_TOKEN_TYPE, random_bond_amount, MIN_AMOUNT, private_key)

        # Step 4: Create Leverage Token with random deposit amount
        random_leverage_amount = get_random_deposit_amount()
        print(Fore.BLUE + f"Creating Leverage Token with amount: {Fore.YELLOW + str(w3.from_wei(random_leverage_amount, 'ether'))} LEV")
        await perform_action('create', LEVERAGE_TOKEN_TYPE, random_leverage_amount, MIN_AMOUNT, private_key)

        # Step 5: Redeem 50% of Bond Token balance
        print(Fore.MAGENTA + 'Redeeming 50% of Bond Token...')
        await perform_action('redeem', BOND_TOKEN_TYPE, random_bond_amount, MIN_AMOUNT, private_key)

        # Step 6: Redeem 50% of Leverage Token balance
        print(Fore.MAGENTA + 'Redeeming 50% of Leverage Token...')
        await perform_action('redeem', LEVERAGE_TOKEN_TYPE, random_leverage_amount, MIN_AMOUNT, private_key)

        print(Fore.YELLOW + f"=== CYCLE COMPLETE FOR WALLET: {Fore.BLUE + wallet_address} ===\n")
        print(Fore.GREEN + "Waiting for 30 seconds before processing the next wallet...")
        await asyncio.sleep(30)

    print(Fore.GREEN + "=== ALL WALLETS PROCESSED ===")

def get_next_run_time(delay_ms):
    """Get formatted next run time"""
    from datetime import datetime, timedelta
    next_run = datetime.now() + timedelta(milliseconds=delay_ms)
    return next_run.strftime("%Y-%m-%d %H:%M:%S")

async def main():
    """Main function to run the process"""
    while True:
        print(Fore.CYAN + Style.BRIGHT + f"Running the process at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        await process_wallets()
        
        # Calculate and print out the next run time (6 hours later)
        delay_ms = 6 * 60 * 60 * 1000  # 6 hours in milliseconds
        next_run_time = get_next_run_time(delay_ms)
        print(Fore.GREEN + f"Process complete. Next run will be at {next_run_time}")
        
        # Wait for 6 hours before next run
        await asyncio.sleep(6 * 60 * 60)

# Required pip packages:
# pip install web3 requests colorama

if __name__ == "__main__":
    try:
        # Set up logging configuration
        import logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )

        # Check Python version compatibility
        import sys
        if sys.version_info < (3, 7):
            raise RuntimeError("This script requires Python 3.7 or higher due to async syntax.")

        # Verify required configuration files exist
        import os
        if not os.path.exists('private_keys.txt'):
            raise FileNotFoundError("private_keys.txt is missing. Please create the file with your wallet private keys.")

        # Print startup message
        print(Fore.GREEN + "Starting Plaza Finance Auto Bot...")
        print(Fore.YELLOW + "Ensure you have a stable internet connection and sufficient gas funds.")

        # Run the main async function
        asyncio.run(main())

    except KeyboardInterrupt:
        print(Fore.RED + "\nScript manually interrupted by user.")
    
    except Exception as e:
        print(Fore.RED + f"An unexpected error occurred: {e}")
        logging.error(f"Unhandled exception: {e}", exc_info=True)
    
    finally:
        print(Fore.CYAN + "Bot shutdown sequence initiated.")
