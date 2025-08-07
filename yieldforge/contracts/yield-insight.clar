;; DeFi Yield Farming DAO Smart Contract v2
;; Completely restructured to avoid any circular dependencies

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-member (err u101))
(define-constant err-strategy-not-found (err u102))
(define-constant err-voting-closed (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-transfer-failed (err u106))
(define-constant err-invalid-strategy (err u107))
(define-constant err-risk-too-high (err u108))

;; Data Variables
(define-data-var strategy-counter uint u0)
(define-data-var member-counter uint u0)
(define-data-var min-stake uint u10000000) ;; 10 STX minimum
(define-data-var max-risk-level uint u70) ;; Max 70% risk tolerance
(define-data-var strategy-duration uint u4320) ;; ~30 days
(define-data-var total-treasury uint u0)

;; Member Management
(define-map dao-members
  principal
  {
    joined-at: uint,
    staked-amount: uint,
    voting-power: uint,
    strategies-proposed: uint,
    successful-strategies: uint,
    total-yield-earned: uint,
    risk-tolerance: uint,
    defi-experience: uint,
    is-validator: bool
  }
)

;; Strategy Proposals with embedded liquidity data
(define-map farming-strategies
  uint
  {
    name: (string-ascii 100),
    description: (string-utf8 800),
    protocol: (string-ascii 50),
    asset-pair: (string-ascii 20),
    expected-apy: uint,
    risk-level: uint,
    duration: uint,
    min-investment: uint,
    max-investment: uint,
    proposer: principal,
    created-at: uint,
    vote-start: uint,
    vote-end: uint,
    yes-votes: uint,
    no-votes: uint,
    weighted-yes: uint,
    weighted-no: uint,
    total-voters: uint,
    status: (string-ascii 20),
    total-allocated: uint,
    current-yield: uint,
    is-active: bool,
    ;; Embedded liquidity pool data
    liquidity-deposited: uint,
    liquidity-yield-total: uint,
    liquidity-participants: uint,
    share-price: uint,
    last-update: uint,
    emergency-paused: bool
  }
)

;; Member Investments in Strategies
(define-map member-investments
  {investor: principal, strategy-id: uint}
  {
    amount-invested: uint,
    shares-owned: uint,
    entry-block: uint,
    yield-claimed: uint,
    is-active: bool
  }
)

;; Voting Records
(define-map strategy-votes
  {strategy-id: uint, voter: principal}
  {
    vote: (string-ascii 10),
    voting-power: uint,
    risk-assessment: uint,
    expected-return: uint,
    timestamp: uint,
    reasoning: (optional (string-utf8 200))
  }
)

;; Join DAO
(define-public (join-farming-dao (stake-amount uint) (risk-tolerance uint) (experience-level uint))
  (let ((member-id (+ (var-get member-counter) u1)))
    (asserts! (is-none (map-get? dao-members tx-sender)) err-not-member)
    (asserts! (>= stake-amount (var-get min-stake)) err-insufficient-balance)
    (asserts! (<= risk-tolerance u100) err-risk-too-high)
    (asserts! (<= experience-level u5) err-invalid-strategy)
    (asserts! (>= (stx-get-balance tx-sender) stake-amount) err-insufficient-balance)
    
    ;; Transfer stake
    (unwrap! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)) err-transfer-failed)
    
    ;; Calculate voting power
    (let ((voting-power (+ stake-amount (* experience-level u1000000))))
      (map-set dao-members tx-sender {
        joined-at: block-height,
        staked-amount: stake-amount,
        voting-power: voting-power,
        strategies-proposed: u0,
        successful-strategies: u0,
        total-yield-earned: u0,
        risk-tolerance: risk-tolerance,
        defi-experience: experience-level,
        is-validator: (>= experience-level u4)
      })
    )
    
    (var-set member-counter member-id)
    (var-set total-treasury (+ (var-get total-treasury) stake-amount))
    
    (print {event: "member-joined", member: tx-sender, stake: stake-amount, experience: experience-level})
    (ok member-id)
  )
)

;; Propose Farming Strategy
(define-public (propose-farming-strategy
  (name (string-ascii 100))
  (description (string-utf8 800))
  (protocol (string-ascii 50))
  (asset-pair (string-ascii 20))
  (expected-apy uint)
  (risk-level uint)
  (min-investment uint)
  (max-investment uint))
  
  (let ((strategy-id (+ (var-get strategy-counter) u1))
        (member-data (unwrap! (map-get? dao-members tx-sender) err-not-member)))
    
    (asserts! (get is-validator member-data) err-not-member)
    (asserts! (<= risk-level (var-get max-risk-level)) err-risk-too-high)
    (asserts! (> expected-apy u0) err-invalid-strategy)
    (asserts! (< min-investment max-investment) err-invalid-strategy)
    
    (map-set farming-strategies strategy-id {
      name: name,
      description: description,
      protocol: protocol,
      asset-pair: asset-pair,
      expected-apy: expected-apy,
      risk-level: risk-level,
      duration: (var-get strategy-duration),
      min-investment: min-investment,
      max-investment: max-investment,
      proposer: tx-sender,
      created-at: block-height,
      vote-start: (+ block-height u144),
      vote-end: (+ block-height u864),
      yes-votes: u0,
      no-votes: u0,
      weighted-yes: u0,
      weighted-no: u0,
      total-voters: u0,
      status: "voting",
      total-allocated: u0,
      current-yield: u0,
      is-active: false,
      ;; Initialize liquidity data
      liquidity-deposited: u0,
      liquidity-yield-total: u0,
      liquidity-participants: u0,
      share-price: u1000000,
      last-update: block-height,
      emergency-paused: false
    })
    
    ;; Update member stats
    (map-set dao-members tx-sender 
      (merge member-data {strategies-proposed: (+ (get strategies-proposed member-data) u1)}))
    
    (var-set strategy-counter strategy-id)
    
    (print {event: "strategy-proposed", strategy-id: strategy-id, protocol: protocol, apy: expected-apy, risk: risk-level})
    (ok strategy-id)
  )
)

;; Vote on Farming Strategy
(define-public (cast-strategy-vote
  (strategy-id uint)
  (vote (string-ascii 10))
  (risk-assessment uint)
  (expected-return uint)
  (reasoning (optional (string-utf8 200))))
  
  (let ((strategy (unwrap! (map-get? farming-strategies strategy-id) err-strategy-not-found))
        (member-data (unwrap! (map-get? dao-members tx-sender) err-not-member))
        (voting-power (get voting-power member-data)))
    
    (asserts! (>= block-height (get vote-start strategy)) err-voting-closed)
    (asserts! (< block-height (get vote-end strategy)) err-voting-closed)
    (asserts! (is-eq (get status strategy) "voting") err-invalid-strategy)
    (asserts! (is-none (map-get? strategy-votes {strategy-id: strategy-id, voter: tx-sender})) err-already-voted)
    (asserts! (or (is-eq vote "yes") (is-eq vote "no")) err-invalid-strategy)
    (asserts! (<= risk-assessment u100) err-risk-too-high)
    
    ;; Risk tolerance check
    (asserts! (or (is-eq vote "no") (<= (get risk-level strategy) (get risk-tolerance member-data))) err-risk-too-high)
    
    ;; Record vote
    (map-set strategy-votes {strategy-id: strategy-id, voter: tx-sender} {
      vote: vote,
      voting-power: voting-power,
      risk-assessment: risk-assessment,
      expected-return: expected-return,
      timestamp: block-height,
      reasoning: reasoning
    })
    
    ;; Update strategy vote totals
    (let ((new-yes-votes (if (is-eq vote "yes") (+ (get yes-votes strategy) u1) (get yes-votes strategy)))
          (new-no-votes (if (is-eq vote "no") (+ (get no-votes strategy) u1) (get no-votes strategy)))
          (new-weighted-yes (if (is-eq vote "yes") (+ (get weighted-yes strategy) voting-power) (get weighted-yes strategy)))
          (new-weighted-no (if (is-eq vote "no") (+ (get weighted-no strategy) voting-power) (get weighted-no strategy))))
      
      (map-set farming-strategies strategy-id 
        (merge strategy {
          yes-votes: new-yes-votes,
          no-votes: new-no-votes,
          weighted-yes: new-weighted-yes,
          weighted-no: new-weighted-no,
          total-voters: (+ (get total-voters strategy) u1)
        }))
    )
    
    (print {event: "strategy-vote", strategy-id: strategy-id, voter: tx-sender, vote: vote, risk-assessment: risk-assessment})
    (ok true)
  )
)

;; Execute Strategy Decision
(define-public (execute-strategy-decision (strategy-id uint))
  (let ((strategy (unwrap! (map-get? farming-strategies strategy-id) err-strategy-not-found)))
    (asserts! (>= block-height (get vote-end strategy)) err-voting-closed)
    (asserts! (is-eq (get status strategy) "voting") err-invalid-strategy)
    
    (let ((total-weighted-votes (+ (get weighted-yes strategy) (get weighted-no strategy)))
          (participation-threshold (/ (var-get total-treasury) u3))
          (strategy-approved (and (>= total-weighted-votes participation-threshold)
                                 (> (get weighted-yes strategy) (get weighted-no strategy)))))
      
      (let ((new-status (if strategy-approved "approved" "rejected")))
        (map-set farming-strategies strategy-id 
          (merge strategy {
            status: new-status,
            is-active: strategy-approved
          }))
        
        (print {event: (if strategy-approved "strategy-approved" "strategy-rejected"), strategy-id: strategy-id})
        (ok strategy-approved)
      )
    )
  )
)

;; Make Investment in Strategy
(define-public (make-investment (strategy-id uint) (amount uint))
  (let ((strategy (unwrap! (map-get? farming-strategies strategy-id) err-strategy-not-found)))
    
    (asserts! (get is-active strategy) err-invalid-strategy)
    (asserts! (>= amount (get min-investment strategy)) err-insufficient-balance)
    (asserts! (<= amount (get max-investment strategy)) err-insufficient-balance)
    (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-balance)
    (asserts! (not (get emergency-paused strategy)) err-invalid-strategy)
    
    ;; Transfer investment
    (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender)) err-transfer-failed)
    
    ;; Calculate shares
    (let ((shares-received (/ (* amount u1000000) (get share-price strategy))))
      
      ;; Record investment
      (map-set member-investments {investor: tx-sender, strategy-id: strategy-id} {
        amount-invested: amount,
        shares-owned: shares-received,
        entry-block: block-height,
        yield-claimed: u0,
        is-active: true
      })
      
      ;; Update strategy liquidity
      (map-set farming-strategies strategy-id 
        (merge strategy {
          total-allocated: (+ (get total-allocated strategy) amount),
          liquidity-deposited: (+ (get liquidity-deposited strategy) amount),
          liquidity-participants: (+ (get liquidity-participants strategy) u1)
        }))
      
      (print {event: "investment-made", strategy-id: strategy-id, investor: tx-sender, amount: amount, shares: shares-received})
      (ok shares-received)
    )
  )
)

;; Update Strategy Performance
(define-public (update-strategy-performance (strategy-id uint) (new-yield uint))
  (let ((strategy (unwrap! (map-get? farming-strategies strategy-id) err-strategy-not-found))
        (member-data (unwrap! (map-get? dao-members tx-sender) err-not-member)))
    
    (asserts! (get is-validator member-data) err-not-member)
    (asserts! (get is-active strategy) err-invalid-strategy)
    
    ;; Calculate new share price based on yield
    (let ((yield-multiplier (+ u1000000 (/ (* new-yield u1000000) u10000)))
          (new-share-price (/ (* (get share-price strategy) yield-multiplier) u1000000)))
      
      (map-set farming-strategies strategy-id 
        (merge strategy {
          current-yield: new-yield,
          liquidity-yield-total: (+ (get liquidity-yield-total strategy) new-yield),
          share-price: new-share-price,
          last-update: block-height
        }))
      
      (print {event: "performance-updated", strategy-id: strategy-id, new-yield: new-yield, share-price: new-share-price})
      (ok true)
    )
  )
)

;; Pause Strategy (Emergency)
(define-public (pause-strategy (strategy-id uint))
  (let ((member-data (unwrap! (map-get? dao-members tx-sender) err-not-member))
        (strategy (unwrap! (map-get? farming-strategies strategy-id) err-strategy-not-found)))
    
    (asserts! (get is-validator member-data) err-not-member)
    
    (map-set farming-strategies strategy-id 
      (merge strategy {emergency-paused: true}))
    
    (print {event: "strategy-paused", strategy-id: strategy-id, trigger: tx-sender})
    (ok true)
  )
)

;; Claim Investment Yield
(define-public (claim-investment-yield (strategy-id uint))
  (let ((strategy (unwrap! (map-get? farming-strategies strategy-id) err-strategy-not-found))
        (investment (unwrap! (map-get? member-investments {investor: tx-sender, strategy-id: strategy-id}) err-not-member))
        (member-data (unwrap! (map-get? dao-members tx-sender) err-not-member)))
    
    (asserts! (get is-active investment) err-invalid-strategy)
    (asserts! (get is-active strategy) err-invalid-strategy)
    
    ;; Calculate claimable yield
    (let ((current-value (/ (* (get shares-owned investment) (get share-price strategy)) u1000000))
          (initial-investment (get amount-invested investment))
          (yield-earned (if (> current-value initial-investment) 
                           (- current-value initial-investment) 
                           u0))
          (claimable-yield (- yield-earned (get yield-claimed investment))))
      
      (asserts! (> claimable-yield u0) err-insufficient-balance)
      
      ;; Update records
      (map-set member-investments {investor: tx-sender, strategy-id: strategy-id}
        (merge investment {yield-claimed: (+ (get yield-claimed investment) claimable-yield)}))
      
      (map-set dao-members tx-sender 
        (merge member-data {total-yield-earned: (+ (get total-yield-earned member-data) claimable-yield)}))
      
      (print {event: "yield-claimed", strategy-id: strategy-id, member: tx-sender, amount: claimable-yield})
      (ok claimable-yield)
    )
  )
)

;; Read-only functions
(define-read-only (get-dao-member (member principal))
  (map-get? dao-members member)
)

(define-read-only (get-farming-strategy (strategy-id uint))
  (map-get? farming-strategies strategy-id)
)

(define-read-only (get-member-investment (investor principal) (strategy-id uint))
  (map-get? member-investments {investor: investor, strategy-id: strategy-id})
)

(define-read-only (get-strategy-vote (strategy-id uint) (voter principal))
  (map-get? strategy-votes {strategy-id: strategy-id, voter: voter})
)

(define-read-only (get-liquidity-info (strategy-id uint))
  (match (map-get? farming-strategies strategy-id)
    strategy (some {
      total-deposited: (get liquidity-deposited strategy),
      total-yield: (get liquidity-yield-total strategy),
      participant-count: (get liquidity-participants strategy),
      share-price: (get share-price strategy),
      last-update: (get last-update strategy),
      emergency-paused: (get emergency-paused strategy)
    })
    none
  )
)

(define-read-only (calculate-expected-returns (strategy-id uint) (amount uint))
  (match (map-get? farming-strategies strategy-id)
    strategy (some {
      expected-daily: (/ (* amount (get expected-apy strategy)) u36500),
      risk-adjusted: (/ (* amount (- (get expected-apy strategy) (get risk-level strategy))) u36500),
      duration-return: (/ (* amount (get expected-apy strategy) (get duration strategy)) u3650000)
    })
    none
  )
)

(define-read-only (get-strategy-metrics (strategy-id uint))
  (match (map-get? farming-strategies strategy-id)
    strategy (some {
      total-votes: (+ (get yes-votes strategy) (get no-votes strategy)),
      approval-rate: (if (> (+ (get yes-votes strategy) (get no-votes strategy)) u0)
                        (/ (* (get yes-votes strategy) u100) (+ (get yes-votes strategy) (get no-votes strategy)))
                        u0),
      weighted-approval: (if (> (+ (get weighted-yes strategy) (get weighted-no strategy)) u0)
                           (/ (* (get weighted-yes strategy) u100) (+ (get weighted-yes strategy) (get weighted-no strategy)))
                           u0),
      current-apy: (get current-yield strategy),
      utilization: (if (> (get max-investment strategy) u0)
                     (/ (* (get total-allocated strategy) u100) (get max-investment strategy))
                     u0)
    })
    none
  )
)

;; Initialize Contract
(define-public (initialize-dao)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (unwrap! (join-farming-dao (var-get min-stake) u50 u5) err-not-member)
    (ok true)
  )
)