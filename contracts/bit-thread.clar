;; BitThread - Decentralized Social Threads with Token-Gated Monetization
;; 
;; A Bitcoin-secured social platform leveraging Stacks Layer 2 for 
;; decentralized content creation, token-gated discussions, and 
;; reputation-based governance with built-in monetization mechanics.
;;
;; Features: Premium threads, STX staking, tip economy, NFT milestones

;; ERROR CONSTANTS
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))  
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-thread-locked (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-invalid-tip (err u107))
(define-constant err-self-tip (err u108))
(define-constant err-thread-not-premium (err u109))
(define-constant err-insufficient-stake (err u110))
(define-constant err-invalid-parent-reply (err u111))

;; PROTOCOL CONFIG
(define-data-var thread-counter uint u0)
(define-data-var reply-counter uint u0)
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum stake
(define-data-var platform-fee-rate uint u250)    ;; 2.5% platform fee
(define-data-var platform-treasury principal contract-owner)

;; CORE DATA MAPS

;; Thread storage with premium gating
(define-map threads
  { thread-id: uint }
  {
    author: principal,
    title: (string-utf8 256),
    content: (string-utf8 2048),
    is-premium: bool,
    premium-price: uint,
    created-at: uint,
    upvotes: uint,
    downvotes: uint,
    tips-received: uint,
    is-locked: bool,
    reply-count: uint
  }
)

;; Nested reply system with thread association
(define-map replies
  { reply-id: uint }
  {
    thread-id: uint,
    author: principal,
    content: (string-utf8 1024),
    created-at: uint,
    upvotes: uint,
    downvotes: uint,
    tips-received: uint,
    parent-reply-id: (optional uint)
  }
)

;; Comprehensive reputation tracking
(define-map user-reputation
  { user: principal }
  {
    total-upvotes: uint,
    total-downvotes: uint,
    threads-created: uint,
    replies-created: uint,
    tips-sent: uint,
    tips-received: uint,
    staked-amount: uint,
    reputation-score: uint
  }
)

;; Voting system with duplicate prevention
(define-map thread-votes
  { thread-id: uint, voter: principal }
  { vote-type: bool }
)

(define-map reply-votes
  { reply-id: uint, voter: principal }
  { vote-type: bool }
)

;; Premium access control
(define-map premium-access
  { thread-id: uint, user: principal }
  { purchased-at: uint }
)

;; Staking mechanism for platform participation
(define-map user-stakes
  { user: principal }
  { amount: uint, locked-until: uint }
)

;; Thread boosting with STX allocation
(define-map thread-boosts
  { thread-id: uint }
  { boost-amount: uint, boosted-by: (list 20 principal) }
)

;; NFT MILESTONES
(define-non-fungible-token thread-milestone uint)

;; HELPER FUNCTIONS

(define-private (get-current-time)
  stacks-block-height
)

(define-private (calculate-reputation-score (upvotes uint) (downvotes uint) (thread-count uint) (reply-count uint))
  (let ((base-score (+ (* upvotes u10) (* thread-count u5) (* reply-count u2))))
    (if (> downvotes u0)
      (/ (* base-score u100) (+ u100 (* downvotes u5)))
      base-score
    )
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-private (is-user-staked (user principal))
  (let ((stake-info (map-get? user-stakes { user: user })))
    (match stake-info
      stake (and (>= (get amount stake) (var-get min-stake-amount))
                 (>= (get-current-time) (get locked-until stake)))
      false
    )
  )
)

(define-private (is-valid-parent-reply (parent-reply-id uint) (thread-id uint))
  (match (map-get? replies { reply-id: parent-reply-id })
    reply-info (is-eq (get thread-id reply-info) thread-id)
    false
  )
)

(define-private (is-valid-reply-id (reply-id uint))
  (is-some (map-get? replies { reply-id: reply-id }))
)

;; READ-ONLY QUERIES

(define-read-only (get-thread (thread-id uint))
  (map-get? threads { thread-id: thread-id })
)

(define-read-only (get-reply (reply-id uint))
  (map-get? replies { reply-id: reply-id })
)

(define-read-only (get-user-reputation (user principal))
  (default-to
    {
      total-upvotes: u0,
      total-downvotes: u0,
      threads-created: u0,
      replies-created: u0,
      tips-sent: u0,
      tips-received: u0,
      staked-amount: u0,
      reputation-score: u0
    }
    (map-get? user-reputation { user: user })
  )
)

(define-read-only (get-thread-count)
  (var-get thread-counter)
)

(define-read-only (get-reply-count)
  (var-get reply-counter)
)

(define-read-only (has-premium-access (thread-id uint) (user principal))
  (let ((thread-info (get-thread thread-id)))
    (match thread-info
      thread (if (get is-premium thread)
               (is-some (map-get? premium-access { thread-id: thread-id, user: user }))
               true)
      false
    )
  )
)

(define-read-only (get-user-vote-on-thread (thread-id uint) (user principal))
  (map-get? thread-votes { thread-id: thread-id, voter: user })
)

(define-read-only (get-user-vote-on-reply (reply-id uint) (user principal))
  (map-get? reply-votes { reply-id: reply-id, voter: user })
)

(define-read-only (get-thread-boost (thread-id uint))
  (default-to
    { boost-amount: u0, boosted-by: (list) }
    (map-get? thread-boosts { thread-id: thread-id })
  )
)

;; CORE FUNCTIONS

;; Create new discussion thread
(define-public (create-thread (title (string-utf8 256)) (content (string-utf8 2048)) (is-premium bool) (premium-price uint))
  (let ((thread-id (+ (var-get thread-counter) u1))
        (current-time (get-current-time)))
    (asserts! (is-user-staked tx-sender) err-insufficient-stake)
    (asserts! (> (len title) u0) err-invalid-amount)
    (asserts! (> (len content) u0) err-invalid-amount)
    (asserts! (or (not is-premium) (> premium-price u0)) err-invalid-amount)
    
    (map-set threads
      { thread-id: thread-id }
      {
        author: tx-sender,
        title: title,
        content: content,
        is-premium: is-premium,
        premium-price: premium-price,
        created-at: current-time,
        upvotes: u0,
        downvotes: u0,
        tips-received: u0,
        is-locked: false,
        reply-count: u0
      }
    )
    
    ;; Update creator reputation
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep
          {
            threads-created: (+ (get threads-created current-rep) u1),
            reputation-score: (calculate-reputation-score
              (get total-upvotes current-rep)
              (get total-downvotes current-rep)
              (+ (get threads-created current-rep) u1)
              (get replies-created current-rep)
            )
          }
        )
      )
    )
    
    (var-set thread-counter thread-id)
    (ok thread-id)
  )
)

;; Create threaded reply with validation
(define-public (create-reply (thread-id uint) (content (string-utf8 1024)) (parent-reply-id (optional uint)))
  (let ((reply-id (+ (var-get reply-counter) u1))
        (current-time (get-current-time))
        (thread-info (unwrap! (get-thread thread-id) err-not-found)))
    
    (asserts! (is-user-staked tx-sender) err-insufficient-stake)
    (asserts! (not (get is-locked thread-info)) err-thread-locked)
    (asserts! (> (len content) u0) err-invalid-amount)
    
    ;; Validate parent reply if specified
    (let ((validated-parent-reply-id 
           (match parent-reply-id
             parent-id (begin
                         (asserts! (is-valid-parent-reply parent-id thread-id) err-invalid-parent-reply)
                         (some parent-id))
             none)))
      
      ;; Check premium access requirements
      (if (get is-premium thread-info)
        (asserts! (has-premium-access thread-id tx-sender) err-thread-not-premium)
        true
      )
      
      (map-set replies
        { reply-id: reply-id }
        {
          thread-id: thread-id,
          author: tx-sender,
          content: content,
          created-at: current-time,
          upvotes: u0,
          downvotes: u0,
          tips-received: u0,
          parent-reply-id: validated-parent-reply-id
        }
      )
      
      ;; Increment thread reply counter
      (map-set threads
        { thread-id: thread-id }
        (merge thread-info { reply-count: (+ (get reply-count thread-info) u1) })
      )
      
      ;; Update user reputation metrics
      (let ((current-rep (get-user-reputation tx-sender)))
        (map-set user-reputation
          { user: tx-sender }
          (merge current-rep
            {
              replies-created: (+ (get replies-created current-rep) u1),
              reputation-score: (calculate-reputation-score
                (get total-upvotes current-rep)
                (get total-downvotes current-rep)
                (get threads-created current-rep)
                (+ (get replies-created current-rep) u1)
              )
            }
          )
        )
      )
      
      (var-set reply-counter reply-id)
      (ok reply-id)
    )
  )
)

;; Purchase premium thread access with STX
(define-public (purchase-premium-access (thread-id uint))
  (let ((thread-info (unwrap! (get-thread thread-id) err-not-found))
        (current-time (get-current-time)))
    
    (asserts! (get is-premium thread-info) err-thread-not-premium)
    (asserts! (is-none (map-get? premium-access { thread-id: thread-id, user: tx-sender })) err-unauthorized)
    
    (let ((price (get premium-price thread-info))
          (author (get author thread-info))
          (platform-fee (calculate-platform-fee price))
          (author-payment (- price platform-fee)))
      
      ;; Process STX payment to author
      (try! (stx-transfer? author-payment tx-sender author))
      
      ;; Platform fee to treasury
      (try! (stx-transfer? platform-fee tx-sender (var-get platform-treasury)))
      
      ;; Grant premium access
      (map-set premium-access
        { thread-id: thread-id, user: tx-sender }
        { purchased-at: current-time }
      )
      
      (ok true)
    )
  )
)

;; VOTING SYSTEM

;; Vote on thread content
(define-public (vote-thread (thread-id uint) (is-upvote bool))
  (let ((thread-info (unwrap! (get-thread thread-id) err-not-found))
        (existing-vote (map-get? thread-votes { thread-id: thread-id, voter: tx-sender })))
    
    (asserts! (is-user-staked tx-sender) err-insufficient-stake)
    (asserts! (is-none existing-vote) err-already-voted)
    (asserts! (not (is-eq tx-sender (get author thread-info))) err-unauthorized)
    
    (map-set thread-votes
      { thread-id: thread-id, voter: tx-sender }
      { vote-type: is-upvote }
    )
    
    (let ((new-upvotes (if is-upvote (+ (get upvotes thread-info) u1) (get upvotes thread-info)))
          (new-downvotes (if is-upvote (get downvotes thread-info) (+ (get downvotes thread-info) u1))))
      
      (map-set threads
        { thread-id: thread-id }
        (merge thread-info
          {
            upvotes: new-upvotes,
            downvotes: new-downvotes
          }
        )
      )
      
      ;; Update author reputation
      (let ((author-rep (get-user-reputation (get author thread-info))))
        (map-set user-reputation
          { user: (get author thread-info) }
          (merge author-rep
            {
              total-upvotes: (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep)),
              total-downvotes: (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1)),
              reputation-score: (calculate-reputation-score
                (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep))
                (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1))
                (get threads-created author-rep)
                (get replies-created author-rep)
              )
            }
          )
        )
      )
    )
    
    (ok true)
  )
)

;; Vote on reply content
(define-public (vote-reply (reply-id uint) (is-upvote bool))
  (let ((reply-info (unwrap! (get-reply reply-id) err-not-found))
        (existing-vote (map-get? reply-votes { reply-id: reply-id, voter: tx-sender })))
    
    (asserts! (is-user-staked tx-sender) err-insufficient-stake)
    (asserts! (is-none existing-vote) err-already-voted)
    (asserts! (not (is-eq tx-sender (get author reply-info))) err-unauthorized)
    
    (map-set reply-votes
      { reply-id: reply-id, voter: tx-sender }
      { vote-type: is-upvote }
    )
    
    (let ((new-upvotes (if is-upvote (+ (get upvotes reply-info) u1) (get upvotes reply-info)))
          (new-downvotes (if is-upvote (get downvotes reply-info) (+ (get downvotes reply-info) u1))))
      
      (map-set replies
        { reply-id: reply-id }
        (merge reply-info
          {
            upvotes: new-upvotes,
            downvotes: new-downvotes
          }
        )
      )
      
      ;; Update author reputation
      (let ((author-rep (get-user-reputation (get author reply-info))))
        (map-set user-reputation
          { user: (get author reply-info) }
          (merge author-rep
            {
              total-upvotes: (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep)),
              total-downvotes: (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1)),
              reputation-score: (calculate-reputation-score
                (if is-upvote (+ (get total-upvotes author-rep) u1) (get total-upvotes author-rep))
                (if is-upvote (get total-downvotes author-rep) (+ (get total-downvotes author-rep) u1))
                (get threads-created author-rep)
                (get replies-created author-rep)
              )
            }
          )
        )
      )
    )
    
    (ok true)
  )
)

;; TIPPING ECONOMY

;; Send STX tip to thread author
(define-public (tip-thread (thread-id uint) (amount uint))
  (let ((thread-info (unwrap! (get-thread thread-id) err-not-found))
        (author (get author thread-info)))
    
    (asserts! (> amount u0) err-invalid-tip)
    (asserts! (not (is-eq tx-sender author)) err-self-tip)
    
    (let ((platform-fee (calculate-platform-fee amount))
          (author-payment (- amount platform-fee)))
      
      ;; Transfer tip to author
      (try! (stx-transfer? author-payment tx-sender author))
      
      ;; Platform fee collection
      (try! (stx-transfer? platform-fee tx-sender (var-get platform-treasury)))
      
      ;; Update thread tip tracking
      (map-set threads
        { thread-id: thread-id }
        (merge thread-info { tips-received: (+ (get tips-received thread-info) amount) })
      )
      
      ;; Update reputation metrics
      (let ((sender-rep (get-user-reputation tx-sender))
            (author-rep (get-user-reputation author)))
        
        (map-set user-reputation
          { user: tx-sender }
          (merge sender-rep { tips-sent: (+ (get tips-sent sender-rep) amount) })
        )
        
        (map-set user-reputation
          { user: author }
          (merge author-rep { tips-received: (+ (get tips-received author-rep) amount) })
        )
      )
      
      (ok true)
    )
  )
)

;; Send STX tip to reply author
(define-public (tip-reply (reply-id uint) (amount uint))
  (let ((reply-info (unwrap! (get-reply reply-id) err-not-found))
        (author (get author reply-info)))
    
    (asserts! (is-valid-reply-id reply-id) err-not-found)
    (asserts! (> amount u0) err-invalid-tip)
    (asserts! (not (is-eq tx-sender author)) err-self-tip)
    
    (let ((platform-fee (calculate-platform-fee amount))
          (author-payment (- amount platform-fee))
          (validated-reply-id reply-id))
      
      ;; Transfer tip to author
      (try! (stx-transfer? author-payment tx-sender author))
      
      ;; Platform fee collection
      (try! (stx-transfer? platform-fee tx-sender (var-get platform-treasury)))
      
      ;; Update reply tip tracking
      (map-set replies
        { reply-id: validated-reply-id }
        (merge reply-info { tips-received: (+ (get tips-received reply-info) amount) })
      )
      
      ;; Update reputation metrics
      (let ((sender-rep (get-user-reputation tx-sender))
            (author-rep (get-user-reputation author)))
        
        (map-set user-reputation
          { user: tx-sender }
          (merge sender-rep { tips-sent: (+ (get tips-sent sender-rep) amount) })
        )
        
        (map-set user-reputation
          { user: author }
          (merge author-rep { tips-received: (+ (get tips-received author-rep) amount) })
        )
      )
      
      (ok true)
    )
  )
)

;; STAKING SYSTEM

;; Stake STX for platform participation
(define-public (stake-tokens (amount uint) (lock-duration uint))
  (let ((current-stake (map-get? user-stakes { user: tx-sender }))
        (current-time (get-current-time)))
    
    (asserts! (>= amount (var-get min-stake-amount)) err-insufficient-stake)
    (asserts! (> lock-duration u0) err-invalid-amount)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (match current-stake
      existing-stake
      (map-set user-stakes
        { user: tx-sender }
        {
          amount: (+ (get amount existing-stake) amount),
          locked-until: (+ current-time lock-duration)
        }
      )
      (map-set user-stakes
        { user: tx-sender }
        {
          amount: amount,
          locked-until: (+ current-time lock-duration)
        }
      )
    )
    
    ;; Update staking reputation
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep
          {
            staked-amount: (+ (get staked-amount current-rep) amount)
          }
        )
      )
    )
    
    (ok true)
  )
)

;; Withdraw staked STX after lock period
(define-public (unstake-tokens (amount uint))
  (let ((stake-info (unwrap! (map-get? user-stakes { user: tx-sender }) err-not-found))
        (current-time (get-current-time)))
    
    (asserts! (>= current-time (get locked-until stake-info)) err-unauthorized)
    (asserts! (<= amount (get amount stake-info)) err-insufficient-balance)
    
    ;; Return STX to user
    (try! (as-contract (stx-transfer? amount tx-sender contract-caller)))
    
    (let ((remaining-amount (- (get amount stake-info) amount)))
      (if (> remaining-amount u0)
        (map-set user-stakes
          { user: tx-sender }
          (merge stake-info { amount: remaining-amount })
        )
        (map-delete user-stakes { user: tx-sender })
      )
    )
    
    ;; Update reputation
    (let ((current-rep (get-user-reputation tx-sender)))
      (map-set user-reputation
        { user: tx-sender }
        (merge current-rep
          {
            staked-amount: (- (get staked-amount current-rep) amount)
          }
        )
      )
    )
    
    (ok true)
  )
)

;; Boost thread visibility with staked tokens
(define-public (boost-thread (thread-id uint) (boost-amount uint))
  (let ((thread-info (unwrap! (get-thread thread-id) err-not-found))
        (current-boost (get-thread-boost thread-id))
        (stake-info (unwrap! (map-get? user-stakes { user: tx-sender }) err-insufficient-stake)))
    
    (asserts! (is-user-staked tx-sender) err-insufficient-stake)
    (asserts! (<= boost-amount (get amount stake-info)) err-insufficient-balance)
    (asserts! (> boost-amount u0) err-invalid-amount)
    (asserts! (is-some (get-thread thread-id)) err-not-found)
    
    ;; Update thread boost metrics
    (let ((verified-thread-id thread-id)
          (verified-boost-amount boost-amount)
          (current-boost-amount (get boost-amount current-boost))
          (current-boosted-by (get boosted-by current-boost)))
      
      (map-set thread-boosts
        { thread-id: verified-thread-id }
        {
          boost-amount: (+ current-boost-amount verified-boost-amount),
          boosted-by: (unwrap! (as-max-len? (append current-boosted-by tx-sender) u20) err-unauthorized)
          }
      )
    )
    
    ;; Allocate staked tokens to boost
    (map-set user-stakes
      { user: tx-sender }
      (merge stake-info { amount: (- (get amount stake-info) boost-amount) })
    )
    
    (ok true)
  )
)

;; CONTENT MODERATION

;; Toggle thread lock status (author only)
(define-public (toggle-thread-lock (thread-id uint))
  (let ((thread-info (unwrap! (get-thread thread-id) err-not-found)))
    (asserts! (is-eq tx-sender (get author thread-info)) err-unauthorized)
    
    (map-set threads
      { thread-id: thread-id }
      (merge thread-info { is-locked: (not (get is-locked thread-info)) })
    )
    
    (ok (not (get is-locked thread-info)))
  )
)

;; NFT MILESTONES

;; Mint achievement NFT for viral threads
(define-public (mint-milestone-nft (thread-id uint))
  (let ((thread-info (unwrap! (get-thread thread-id) err-not-found)))
    (asserts! (is-eq tx-sender (get author thread-info)) err-unauthorized)
    (asserts! (>= (get upvotes thread-info) u100) err-unauthorized)
    
    (try! (nft-mint? thread-milestone thread-id tx-sender))
    (ok thread-id)
  )
)

;; ADMIN FUNCTIONS

;; Update platform fee structure
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

;; Adjust minimum staking requirements
(define-public (set-min-stake-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-amount u0) err-invalid-amount)
    (var-set min-stake-amount new-amount)
    (ok true)
  )
)

;; Update platform treasury address
(define-public (set-platform-treasury (new-treasury principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-eq new-treasury 'SP000000000000000000002Q6VF78)) err-invalid-amount)
    (var-set platform-treasury new-treasury)
    (ok true)
  )
)

