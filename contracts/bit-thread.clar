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