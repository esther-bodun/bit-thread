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