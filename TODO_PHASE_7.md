# FameFit Phase 7: FameCoin Currency System

**Status**: Planning  
**Duration**: 3-4 weeks  
**Impact**: High - Secondary economy and monetization support

Implement a comprehensive secondary currency system that complements XP with spendable rewards.

## Core Implementation

### 1. FameCoin Economy Infrastructure

**CloudKit Schema Design**

- [ ] FameCoin balance tracking
- [ ] Transaction history storage
- [ ] Earning source tracking
- [ ] Spending category analytics

**Earning Mechanisms**

- [ ] Workout completion: 0.1x minutes (3 coins for 30min)
- [ ] Personal records: +10 coins
- [ ] Streak maintenance: 1 coin per consecutive day
- [ ] Kudos received: 1 coin (daily cap: 10)
- [ ] New followers: 2 coins (daily cap: 20)
- [ ] Achievement completion: 5-50 coins by difficulty
- [ ] **Sharing bonuses: 5-25 coins per verified share**
- [ ] Daily login bonus: 2 coins

### 2. FameCoin Store & Spending

**Cosmetic Upgrades**

- [ ] Premium character skins: 100-500 coins
- [ ] Custom workout messages: 50 coins
- [ ] Profile decorations/frames: 25-200 coins
- [ ] Animated profile badges: 150 coins
- [ ] Custom app themes: 300 coins

**Gameplay Boosters**

- [ ] 2x XP booster (next workout): 50 coins
- [ ] Streak protection (skip rest day): 25 coins
- [ ] Double kudos weekend: 100 coins
- [ ] Achievement boost: 75 coins
- [ ] Share reward multiplier: 30 coins

**Social Features**

- [ ] Highlight workout in feed: 10 coins
- [ ] Profile spotlight (discovery): 200 coins
- [ ] Custom workout celebration: 100 coins
- [ ] Premium share templates: 25 coins

### 3. Transaction Management

**Balance & History Tracking**

- [ ] Real-time balance updates
- [ ] Complete transaction history
- [ ] Earning source breakdown
- [ ] Spending category analytics

**Security & Validation**

- [ ] Server-side transaction validation
- [ ] Anti-manipulation measures
- [ ] Rate limiting for earnings
- [ ] Audit trail for all transactions

### 4. Economy Balancing

**Target Metrics**

- [ ] Earning rate: 20-40 coins per active day
- [ ] Weekly accumulation: 50-100 coins
- [ ] Spending distribution across categories
- [ ] Healthy earn/spend ratio maintenance

**Monitoring & Adjustment**

- [ ] Real-time economy monitoring
- [ ] Inflation/deflation detection
- [ ] Dynamic earning rate adjustments
- [ ] Seasonal bonus campaigns

## Integration with Sharing System

- Verified shares earn 5-25 FameCoins based on platform and engagement
- Premium sharing templates available for purchase
- Share streak bonuses using FameCoins
- Cross-platform sharing diversity bonuses

## CloudKit Schema

```
FameCoinTransaction (Private Database)
- transactionId: String (CKRecord.ID)
- userId: String (Reference) - QUERYABLE
- timestamp: Date - QUERYABLE, SORTABLE
- type: String ("earned", "spent", "bonus", "refund") - QUERYABLE
- category: String - QUERYABLE
- amount: Int64
- balance: Int64
- source: String (detailed source/reason)
- metadata: String (JSON for additional data)

FameCoinBalance (Private Database)
- userId: String (CKRecord.ID) - Primary Key
- currentBalance: Int64
- totalEarned: Int64
- totalSpent: Int64
- lastUpdated: Date
- balanceVersion: Int64 (for conflict resolution)

StoreItem (Public Database)
- itemId: String (CKRecord.ID)
- category: String - QUERYABLE
- name: String
- description: String
- price: Int64
- isActive: Int64 - QUERYABLE
- availableFrom: Date
- availableUntil: Date
- purchaseLimit: Int64
- imageAsset: CKAsset
```

## UI/UX Components

### FameCoin Display

- [ ] Balance indicator in main navigation
- [ ] Animated coin counter for earnings
- [ ] Transaction history view
- [ ] Earning breakdown charts

### Store Interface

- [ ] Categorized item browsing
- [ ] Item preview functionality
- [ ] Purchase confirmation flow
- [ ] Owned items gallery

### Notification System

- [ ] Earning notifications
- [ ] Low balance reminders
- [ ] Sale/promotion alerts
- [ ] Purchase confirmations

## Security Measures

### Anti-Fraud Protection

- Server-side balance validation
- Transaction rate limiting
- Suspicious activity detection
- Regular audit reconciliation

### Data Integrity

- Atomic transaction processing
- Balance version checking
- Rollback capabilities
- Backup transaction logs

## Analytics & Monitoring

### Key Metrics

- Daily active spenders
- Average revenue per user (ARPU)
- Coin velocity (earn/spend ratio)
- Popular purchase categories
- Retention impact analysis

### A/B Testing Framework

- Pricing experiments
- Earning rate optimization
- Store layout variations
- Promotion effectiveness

## Future Monetization

### Premium Currency (Phase 8+)

- Real money purchases of FameCoins
- Subscription tiers with bonus coins
- Limited-time offers
- Gift card integration

### Marketplace Features

- User-generated content sales
- Workout plan marketplace
- Character design competitions
- Community challenges with entry fees

## Implementation Timeline

### Week 1: Infrastructure

- CloudKit schema setup
- Transaction service implementation
- Balance management system
- Security framework

### Week 2: Earning Systems

- Workout completion integration
- Achievement rewards
- Social action rewards
- Daily bonus system

### Week 3: Store Development

- Store UI/UX
- Item catalog
- Purchase flow
- Inventory management

### Week 4: Polish & Testing

- Analytics integration
- Performance optimization
- Security testing
- Economy balancing

## Success Criteria

- 70% of active users earn coins daily
- 40% of users make at least one purchase per month
- Less than 0.1% fraud rate
- 90% transaction success rate
- Positive impact on retention (+15%)

---

## Additional Features for Future Consideration

### Workout Buddies - Second Degree Connections

- Create `SecondDegreeConnections` denormalized cache table
- Implement "Workout Buddies" feature based on:
  - Similar workout times (±1 hour window)
  - Common workout types
  - Comparable fitness levels (XP-based)
- Show mutual connections in user discovery
- Background job to maintain connection cache
- Suggested follows based on friends-of-friends
- Leverage workout data for social connections instead of complex graph traversal

---

Last Updated: 2025-07-31 - Phase 7 Planning
