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