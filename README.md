# Token Gated Access to Private Content
 
# Private Gate - NFT-Gated Content Access

Private Gate is a Clarity smart contract that enables token-gated access to premium content. Only NFT holders can view protected content, creating an exclusive experience for token owners.

## Overview

This contract implements a system where:

1. Content creators can add premium content to the blockchain (represented by content hashes)
2. Access to content is restricted to holders of the "premium-access" NFT
3. Different content can have different access levels
4. Access attempts are logged for analytics

## Contract Functions

### For Administrators

- `mint-access-token`: Mint a new access NFT to a recipient
- `transfer-contract-ownership`: Transfer contract control to a new owner

### For Content Creators

- `add-content`: Add new content with title, content hash, and access level
- `update-content`: Update existing content details
- `toggle-content-status`: Enable or disable access to specific content

### For Users

- `get-content`: Retrieve content if the user has appropriate access
- `has-access`: Check if a user has access to specific content

### Read-Only Functions

- `get-content-metadata`: View public metadata about content without accessing it
- `get-content-count`: Get the total number of content items
- `get-token-count`: Get the total number of access tokens minted

## Usage Examples

### Adding Content (for creators)

```clarity
(contract-call? .private-gate add-content "Premium Tutorial" 0x8a9c5262a93322e9d1ff729d16fd68f3c9ef743833e81e53455e5a5c8757b9bf u1)
```

### Accessing Content (for users with NFT)

```clarity
(contract-call? .private-gate get-content u1)
```

### Checking Access Rights

```clarity
(contract-call? .private-gate has-access tx-sender u1)
```

## Implementation Details

- Content is stored as hashes, with the actual content hosted off-chain
- Access is verified by checking NFT ownership
- The contract supports multiple access tiers for different content levels
- All access attempts are logged for analytics purposes

## Getting Started

1. Deploy the contract using Clarinet
2. Mint access tokens to users
3. Add content with appropriate access levels
4. Users with tokens can access the content

## Security Considerations

- Only the contract owner can mint new access tokens
- Content creators can only modify their own content
- Access checks are performed on every content retrieval