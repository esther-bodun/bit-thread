# BitThread - Decentralized Social Threads

[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-blue)](https://stacks.co/)
[![Bitcoin](https://img.shields.io/badge/Secured%20by-Bitcoin-orange)](https://bitcoin.org/)

A Bitcoin-secured social platform leveraging Stacks Layer 2 for decentralized content creation, token-gated discussions, and reputation-based governance with built-in monetization mechanics.

## Features

- **Premium Threads**: Token-gated content with STX pricing
- **STX Staking**: Stake tokens for platform participation
- **Tip Economy**: Direct monetization through microtransactions
- **NFT Milestones**: Achievement tokens for viral content
- **Reputation System**: Algorithmic scoring based on community engagement
- **Nested Replies**: Hierarchical discussion threads
- **Content Moderation**: Author-controlled thread locking

## System Overview

BitThread operates as a decentralized social platform where users stake STX tokens to participate in discussions. The platform implements a token-gated economy where premium content requires payment, tips flow directly to creators, and reputation scores determine user standing in the community.

### Core Components

1. **Thread Management**: Create and manage discussion threads with optional premium gating
2. **Reply System**: Nested comments with parent-child relationships
3. **Voting Mechanism**: Community-driven content curation through upvotes/downvotes
4. **Monetization Layer**: STX-based tipping and premium access purchases
5. **Staking Protocol**: Token commitment for platform participation rights
6. **Reputation Engine**: Algorithmic scoring based on community interactions

## Contract Architecture

The BitThread smart contract is structured around several key data maps and operational functions:

### Data Storage Layer

```
├── Core Content
│   ├── threads (Thread metadata and content)
│   ├── replies (Nested reply system)
│   └── user-reputation (Comprehensive reputation tracking)
├── Interaction Layer
│   ├── thread-votes (Voting history)
│   ├── reply-votes (Reply voting)
│   └── premium-access (Paid content access)
├── Economic Layer
│   ├── user-stakes (STX staking records)
│   └── thread-boosts (Visibility enhancement)
└── Achievement Layer
    └── thread-milestone (NFT milestone tokens)
```

### Function Categories

**Content Creation**

- `create-thread`: Initialize new discussion threads
- `create-reply`: Add nested replies to existing threads

**Economic Functions**

- `purchase-premium-access`: Buy access to token-gated content
- `tip-thread` / `tip-reply`: Send STX tips to content creators
- `stake-tokens` / `unstake-tokens`: Manage platform participation stakes

**Community Interaction**

- `vote-thread` / `vote-reply`: Community curation through voting
- `boost-thread`: Enhance thread visibility through token allocation

**Governance & Moderation**

- `toggle-thread-lock`: Author-controlled content moderation
- `mint-milestone-nft`: Achievement tokens for viral content

## Data Flow

### Thread Creation Flow

```
User Stakes STX → Create Thread → Update Reputation → Thread Available
```

### Premium Access Flow

```
User Pays STX → Platform Fee Deducted → Author Receives Payment → Access Granted
```

### Reputation Calculation

```
Base Score = (Upvotes × 10) + (Threads × 5) + (Replies × 2)
Final Score = Base Score × 100 / (100 + Downvotes × 5)
```

### Tipping Economy

```
Tip Amount → Platform Fee (2.5%) → Author Receives (97.5%) → Reputation Updated
```

## Technical Specifications

### Platform Economics

- **Minimum Stake**: 1 STX (1,000,000 micro-STX)
- **Platform Fee**: 2.5% on all transactions
- **Reputation Multipliers**:
  - Upvotes: 10x weight
  - Thread Creation: 5x weight
  - Reply Creation: 2x weight
  - Downvote Penalty: 5x divisor

### Security Features

- **Staking Requirements**: All interactions require minimum STX stake
- **Duplicate Prevention**: Anti-spam voting mechanisms
- **Access Control**: Premium content gating with payment verification
- **Self-Interaction Prevention**: Users cannot tip or vote on their own content

### NFT Milestones

- **Viral Threshold**: 100+ upvotes required for milestone NFT
- **Author Exclusive**: Only thread authors can mint milestone NFTs
- **Unique Tokens**: Each thread can generate one milestone NFT

## Getting Started

### Prerequisites

- Stacks wallet with STX tokens
- Minimum 1 STX for platform participation
- Compatible Stacks-enabled application

### Basic Usage

1. **Stake Tokens**: Commit minimum 1 STX to participate
2. **Create Content**: Post threads (free or premium)
3. **Engage**: Vote, reply, and tip quality content
4. **Earn**: Receive tips and build reputation
5. **Achieve**: Mint NFT milestones for viral content

### Premium Features

- **Token-Gated Threads**: Set STX price for exclusive content
- **Enhanced Visibility**: Boost threads with staked tokens
- **Milestone NFTs**: Collectible achievements for successful creators

## Contract Deployment

The contract is deployed on the Stacks blockchain and secured by Bitcoin's proof-of-work consensus mechanism. All transactions are immutable and transparent on the blockchain.

### Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner-only function |
| u101 | Resource not found |
| u102 | Unauthorized access |
| u103 | Insufficient balance |
| u104 | Invalid amount |
| u105 | Thread locked |
| u106 | Already voted |
| u107 | Invalid tip |
| u108 | Self-tip attempt |
| u109 | Thread not premium |
| u110 | Insufficient stake |
| u111 | Invalid parent reply |

## Contributing

BitThread is an open-source project. Contributions are welcome through:

- Bug reports and feature requests
- Code improvements and optimizations
- Documentation enhancements
- Community feedback and testing
