
# ERC721RQ

Built on top of Openzeppelins ERC721, this implementation allows users to lend their NFTs for ETH


## Built on Solidity

To use this implementation (post mint)

A user can call 2 functions for lending

- leaseDetailedERC721RQ (This allows the user to lend to a specific address)
- leaseERC721RQ (This allows the user to lend without requiring a specific address)

Both functions will require 3 parameters (Token ID, ETH value, Length of days)


## The lendee will then call the following function

- payToLease

This will require the token ID as a parameter and the eth value to be sent.

The ETH will automatically be sent to the lender and the ownership will point to the lendee

## Once the time period has completed

The original owner of the NFT will call the function

- endLease

This will require the token ID as a parameter

Finally reseting the lending phase and returning ownership.


## THE NFT NEVER LEAVES

This is a pseudo loan technique which only alters the ownerOf function to point to another address during an active lending period.
The original owner will maintain the token in their wallet and will not be able to sell/transfer during the lending period.

