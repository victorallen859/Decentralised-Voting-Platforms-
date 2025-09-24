# 🗳️ Decentralized Voting Platform

A robust and secure decentralized voting platform built on the Stacks blockchain using Clarity smart contracts. This platform enables transparent, tamper-proof voting with advanced features like delegation, reputation-based weighting, and comprehensive poll management.

## 🌟 Features

- **🔐 Secure Voting**: Blockchain-based voting system ensuring transparency and immutability
- **👥 Voter Registration**: Simple registration system with reputation tracking
- **🏆 Reputation System**: Vote weight increases based on participation and reputation
- **🤝 Vote Delegation**: Ability to delegate voting power to trusted representatives
- **⏰ Time-bound Polls**: Configurable start and end times for voting periods
- **📊 Real-time Results**: Live vote counting and result tracking
- **💰 Platform Fees**: Configurable fee system for poll creation
- **🎯 Minimum Thresholds**: Customizable minimum vote requirements for poll validity
- **🔄 Automatic Finalization**: Smart contract automatically determines winning options

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks CLI](https://docs.stacks.co/understand-stacks/command-line-interface) (optional)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/your-username/Decentralised-Voting-Platforms.git
cd Decentralised-Voting-Platforms
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📋 Usage Guide

### 1. Voter Registration

Before participating in any poll, users must register as voters:

```clarity
(contract-call? .Decentralised-Voting-Platforms register-voter)
```

### 2. Creating a Poll

Poll creators must pay a platform fee (default: 0.1 STX) and provide:

```clarity
(contract-call? .Decentralised-Voting-Platforms create-poll
  "Climate Action Poll"                    ;; title
  "Should we implement carbon credits?"     ;; description
  (list "Yes" "No" "Abstain")              ;; options (up to 10)
  u1440                                     ;; duration (blocks, ~10 days)
  u10                                       ;; minimum vote threshold
)
```

### 3. Casting Votes

Registered voters can cast their votes during the active polling period:

```clarity
(contract-call? .Decentralised-Voting-Platforms cast-vote
  u0  ;; poll-id
  u0  ;; option-id (0 for "Yes", 1 for "No", 2 for "Abstain")
)
```

### 4. Vote Delegation

Voters can delegate their voting power to trusted representatives:

```clarity
(contract-call? .Decentralised-Voting-Platforms delegate-vote
  u0                           ;; poll-id
  'SP1234...TRUSTED-DELEGATE   ;; delegate principal
  u5                           ;; weight to delegate
)
```

### 5. Finalizing Polls

After the voting period ends and minimum threshold is met:

```clarity
(contract-call? .Decentralised-Voting-Platforms finalize-poll u0)
```

## 🔍 Query Functions

### Get Poll Information
```clarity
(contract-call? .Decentralised-Voting-Platforms get-poll u0)
```

### Check Poll Results
```clarity
(contract-call? .Decentralised-Voting-Platforms get-poll-results u0)
```

### View Voter Information
```clarity
(contract-call? .Decentralised-Voting-Platforms get-voter-info 'SP1234...VOTER)
```

### Check if Poll is Active
```clarity
(contract-call? .Decentralised-Voting-Platforms is-poll-active u0)
```

## 🏗️ Contract Architecture

### Data Maps
- **`polls`**: Stores poll metadata, timing, and results
- **`poll-options`**: Contains voting options and their vote counts
- **`votes`**: Records individual votes with weights and timestamps
- **`voter-registration`**: Manages voter profiles and reputation
- **`poll-delegates`**: Tracks vote delegation relationships

### Key Functions
- **Public Functions**: `register-voter`, `create-poll`, `cast-vote`, `delegate-vote`, `finalize-poll`
- **Admin Functions**: `update-platform-fee`, `transfer-admin`
- **Read-Only Functions**: Various getters for querying contract state

## ⚡ Reputation System

- **Initial Reputation**: 100 points upon registration
- **Vote Bonus**: +10 reputation points per vote cast
- **Weight Calculation**: Base weight (1) + reputation bonus
- **Progressive Influence**: More active voters gain more influence

## 💰 Economic Model

- **Platform Fee**: Paid by poll creators (default: 0.1 STX)
- **Admin Control**: Fee adjustable by contract admin
- **Revenue Distribution**: Fees collected by platform admin
- **Threshold Requirements**: Minimum votes required for poll validity

## 🔒 Security Features

- **Single Vote Enforcement**: Prevents double voting
- **Time-bound Validation**: Votes only accepted during active periods
- **Delegation Safeguards**: Prevents self-delegation and circular delegation
- **Threshold Protection**: Ensures poll legitimacy through minimum participation
- **Admin Controls**: Secure administrative functions

## 🚨 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1001 | ERR-NOT-AUTHORIZED | Unauthorized access attempt |
| 1002 | ERR-POLL-NOT-FOUND | Poll ID does not exist |
| 1003 | ERR-POLL-ENDED | Voting period has ended |
| 1004 | ERR-POLL-NOT-STARTED | Voting period hasn't started |
| 1005 | ERR-ALREADY-VOTED | User has already voted |
| 1006 | ERR-INVALID-OPTION | Selected option doesn't exist |
| 1007 | ERR-INSUFFICIENT-THRESHOLD | Not enough votes to finalize |
| 1008 | ERR-POLL-STILL-ACTIVE | Poll is still accepting votes |
| 1009 | ERR-VOTER-NOT-REGISTERED | User must register first |
| 1010 | ERR-INVALID-DELEGATE | Invalid delegation target |
| 1011 | ERR-INSUFFICIENT-FUNDS | Not enough STX for platform fee |

## 🧪 Testing

Run the test suite to verify contract functionality:

```bash
clarinet test
```


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


---

**⚠️ Disclaimer**: This smart contract is for educational and demonstration purposes. Please conduct thorough testing and auditing before using in production environments.
