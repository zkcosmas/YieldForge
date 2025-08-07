# DeFi Yield Farming DAO Smart Contract

A decentralized autonomous organization (DAO) smart contract built on Stacks blockchain, specialized for DeFi yield farming strategy governance and investment management.

## 🌟 Overview

This smart contract enables community-driven yield farming strategies through a democratic governance system. Members can propose, vote on, and invest in various DeFi protocols while managing risk through collective decision-making.

## ✨ Key Features

### 🏛️ **Governance System**
- **Democratic Voting**: Weighted voting based on stake and experience
- **Strategy Proposals**: Validators can propose yield farming strategies
- **Risk Assessment**: Built-in risk tolerance matching for members
- **Experience Tracking**: DeFi experience levels influence voting power

### 💰 **Investment Management**
- **Liquidity Pools**: Automated pool creation for approved strategies
- **Yield Distribution**: Dynamic share price calculation based on returns
- **Portfolio Diversification**: Multiple strategy support
- **Emergency Exit**: Safety mechanism for volatile conditions

### 🛡️ **Risk Management**
- **Risk Tolerance Levels**: 0-100 scale for member preferences
- **Maximum Risk Caps**: Configurable risk limits (default: 70%)
- **Validator System**: Experienced members validate strategies
- **Emergency Controls**: Circuit breakers for emergency situations

## 📋 Contract Structure

### Core Data Maps
- **`members`**: Member profiles with staking, experience, and risk data
- **`strategies`**: Yield farming strategy proposals and status
- **`pools`**: Liquidity pool management and performance tracking
- **`investments`**: Individual member investment records
- **`votes`**: Voting records with risk assessments

### Key Constants
```clarity
min-stake: 10 STX          // Minimum stake to join DAO
max-risk-level: 70%        // Maximum allowed risk level
strategy-duration: ~30 days // Default strategy duration
```

## 🚀 Getting Started

### Prerequisites
- Stacks wallet with STX tokens
- Minimum 10 STX for initial membership
- Understanding of DeFi risks

### Joining the DAO

```clarity
(join-dao 
  stake-amount      ;; uint - STX amount to stake (minimum 10 STX)
  risk-tolerance    ;; uint - Risk tolerance 0-100
  experience-level  ;; uint - DeFi experience 1-5
)
```

**Example:**
```clarity
;; Join with 50 STX, 60% risk tolerance, experience level 3
(join-dao u50000000 u60 u3)
```

## 📖 Usage Guide

### 1. **Becoming a Member**
```clarity
(join-dao u10000000 u50 u3) ;; 10 STX, 50% risk, level 3 experience
```
- Minimum 10 STX stake required
- Risk tolerance (0-100): Your maximum acceptable risk level
- Experience level (1-5): Affects voting power and validator status

### 2. **Proposing Strategies** (Validators Only)
```clarity
(propose-strategy
  "Compound STX Strategy"           ;; Strategy name
  u"Yield farming on Compound..."   ;; Description
  "compound"                        ;; Protocol
  "STX-USDC"                       ;; Asset pair
  u1250                            ;; Expected APY (12.5%)
  u45                              ;; Risk level (45%)
  u5000000                         ;; Min investment (5 STX)
  u100000000)                      ;; Max investment (100 STX)
```

### 3. **Voting on Strategies**
```clarity
(vote-on-strategy
  u1                               ;; Strategy ID
  "yes"                           ;; Vote (yes/no)
  u40                             ;; Risk assessment
  u1200                           ;; Expected return estimate
  (some u"High yield potential"))  ;; Optional reasoning
```

### 4. **Investing in Approved Strategies**
```clarity
(invest-in-strategy u1 u25000000) ;; Invest 25 STX in strategy #1
```

### 5. **Monitoring Performance**
```clarity
;; Get strategy details
(get-strategy u1)

;; Check your investment
(get-investment tx-sender u1)

;; View pool performance
(get-pool u1)
```

## 🎯 Strategy Lifecycle

1. **Proposal Phase**: Validators propose strategies with risk/return profiles
2. **Voting Phase**: 6-day voting period with weighted community votes
3. **Finalization**: Automatic approval if >33% participation and majority support
4. **Pool Creation**: Liquidity pool automatically created for approved strategies
5. **Investment Phase**: Members can invest within defined limits
6. **Yield Tracking**: Validators update yields, share prices adjust automatically
7. **Emergency Exit**: Safety mechanism for market volatility

## 📊 Risk Management Features

### Member Risk Profiles
- **Risk Tolerance**: Personal risk ceiling (0-100%)
- **Experience Weighting**: Higher experience = more voting power
- **Validator Status**: Level 4+ experience members can validate

### Strategy Risk Controls
- **Maximum Risk Cap**: Global 70% maximum
- **Risk-Vote Matching**: Members can only vote "yes" on strategies within their risk tolerance
- **Emergency Exit**: Validators can trigger emergency exits

### Investment Protections
- **Minimum/Maximum Limits**: Per-strategy investment bounds
- **Pool Share System**: Fair distribution based on entry timing
- **Yield Updates**: Regular performance tracking

## 🔍 Read-Only Functions

### Member Information
```clarity
(get-member principal)           ;; Get member profile
```

### Strategy Data
```clarity
(get-strategy strategy-id)       ;; Get strategy details
(calculate-returns strategy-id amount) ;; Calculate expected returns
```

### Investment Tracking
```clarity
(get-investment member strategy-id) ;; Get investment details
(get-pool pool-id)               ;; Get pool performance
(get-vote strategy-id voter)     ;; Get voting record
```

## ⚠️ Important Considerations

### Risks
- **Smart Contract Risk**: Code is experimental and unaudited
- **Market Risk**: DeFi investments carry inherent volatility
- **Governance Risk**: Majority decisions may not align with individual preferences
- **Liquidity Risk**: Emergency exits may be necessary during market stress

### Best Practices
- Start with small investments to understand the system
- Carefully review strategy proposals before voting
- Set appropriate risk tolerance based on your financial situation
- Regularly monitor your investments and pool performance

## 🛠️ Technical Details

### Built On
- **Blockchain**: Stacks
- **Language**: Clarity Smart Contract Language
- **Token Standard**: STX (native Stacks token)

### Architecture
- **Modular Design**: Separate concerns for governance, investment, and risk management
- **Event Logging**: Comprehensive event emissions for transparency
- **Gas Optimized**: Efficient data structures and function calls

## 📚 Events

The contract emits various events for monitoring:
- `member-joined`: New member registration
- `strategy-proposed`: New strategy proposals
- `strategy-vote`: Voting activity
- `investment-made`: New investments
- `yield-updated`: Performance updates
- `emergency-exit-triggered`: Safety activations

## 🤝 Contributing

This is a community-driven project. Members can:
- Propose new strategies (validators)
- Vote on governance decisions
- Provide feedback on risk management
- Suggest improvements to the protocol
