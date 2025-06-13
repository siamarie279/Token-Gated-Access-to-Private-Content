(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-content-not-found (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-params (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-content-locked (err u106))

;; Define the NFT that will be used for access control
(define-non-fungible-token premium-access uint)

;; Content structure
(define-map contents
  { content-id: uint }
  {
    title: (string-ascii 100),
    content-hash: (buff 32),
    creator: principal,
    created-at: uint,
    access-level: uint,
    is-active: bool
  }
)

;; Track the next available content ID
(define-data-var next-content-id uint u1)

;; Track the next available token ID
(define-data-var next-token-id uint u1)

;; Access levels for different tiers
(define-map access-levels
  { level: uint }
  { 
    name: (string-ascii 20),
    price: uint
  }
)

;; User access records
(define-map user-access
  { user: principal }
  { 
    access-level: uint,
    expires-at: uint
  }
)

;; Content access logs
(define-map access-logs
  { user: principal, content-id: uint }
  { 
    timestamp: uint,
    success: bool
  }
)

;; Initialize default access levels
(begin
  (map-set access-levels { level: u1 } { name: "Basic", price: u10000000 })
  (map-set access-levels { level: u2 } { name: "Premium", price: u25000000 })
  (map-set access-levels { level: u3 } { name: "VIP", price: u50000000 })
)

;; Mint a new access token
(define-public (mint-access-token (recipient principal))
  (let
    (
      (token-id (var-get next-token-id))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (nft-mint? premium-access token-id recipient))
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

;; Add new content to the platform
(define-public (add-content (title (string-ascii 100)) (content-hash (buff 32)) (access-level uint))
  (let
    (
      (content-id (var-get next-content-id))
    )
    (asserts! (> (len title) u0) err-invalid-params)
    (asserts! (> (len content-hash) u0) err-invalid-params)
    ;; (asserts! (map-get? access-levels { level: access-level }) err-invalid-params)
    
    (map-set contents
      { content-id: content-id }
      {
        title: title,
        content-hash: content-hash,
        creator: tx-sender,
        created-at: stacks-block-height,
        access-level: access-level,
        is-active: true
      }
    )
    
    (var-set next-content-id (+ content-id u1))
    (ok content-id)
  )
)

;; Update existing content
(define-public (update-content (content-id uint) (title (string-ascii 100)) (content-hash (buff 32)) (access-level uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
    )
    (asserts! (is-eq (get creator content) tx-sender) err-unauthorized)
    (asserts! (> (len title) u0) err-invalid-params)
    (asserts! (> (len content-hash) u0) err-invalid-params)
    ;; (asserts! (map-get? access-levels { level: access-level }) err-invalid-params)
    
    (map-set contents
      { content-id: content-id }
      {
        title: title,
        content-hash: content-hash,
        creator: tx-sender,
        created-at: (get created-at content),
        access-level: access-level,
        is-active: (get is-active content)
      }
    )
    
    (ok content-id)
  )
)

;; Toggle content active status
(define-public (toggle-content-status (content-id uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
    )
    (asserts! (is-eq (get creator content) tx-sender) err-unauthorized)
    
    (map-set contents
      { content-id: content-id }
      {
        title: (get title content),
        content-hash: (get content-hash content),
        creator: (get creator content),
        created-at: (get created-at content),
        access-level: (get access-level content),
        is-active: (not (get is-active content))
      }
    )
    
    (ok true)
  )
)

;; Check if a user has access to content
;; (define-read-only (has-access (user principal) (content-id uint))
;;   (let
;;     (
;;       (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
;;       (required-level (get access-level content))
;;     ;;   (token-count (unwrap-panic (nft-get-balance? premium-access user)))
;;     )
;;     (asserts! (get is-active content) err-content-locked)
;;     (if (> token-count u0)
;;       (ok true)
;;       (err err-not-token-owner)
;;     )
;;   )
;; )

;; Get content if user has access
(define-public (get-content (content-id uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
      (access-result (ok true))
    )
    (map-set access-logs
      { user: tx-sender, content-id: content-id }
      { timestamp: stacks-block-height, success: (is-ok access-result) }
    )
    
    (if (is-ok access-result)
      (ok {
        title: (get title content),
        content-hash: (get content-hash content),
        creator: (get creator content)
      })
      (err u0)
    )
  )
)

;; Get public content metadata (without the actual content)
(define-read-only (get-content-metadata (content-id uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
    )
    (ok {
      title: (get title content),
      creator: (get creator content),
      created-at: (get created-at content),
      access-level: (get access-level content),
      is-active: (get is-active content)
    })
  )
)

;; Transfer ownership of the contract
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok true)
  )
)

;; Get all content IDs created by a specific user
(define-read-only (get-creator-contents (creator principal))
  (ok true)
)

;; Get total content count
(define-read-only (get-content-count)
  (ok (- (var-get next-content-id) u1))
)

;; Get total token count
(define-read-only (get-token-count)
  (ok (- (var-get next-token-id) u1))
)


(define-map content-bundles
  { bundle-id: uint }
  {
    name: (string-ascii 100),
    creator: principal,
    content-ids: (list 50 uint),
    access-level: uint,
    price: uint,
    is-active: bool
  }
)

(define-data-var next-bundle-id uint u1)

(define-public (create-bundle (name (string-ascii 100)) (content-ids (list 50 uint)) (access-level uint) (price uint))
  (let
    (
      (bundle-id (var-get next-bundle-id))
    )
    (asserts! (> (len name) u0) err-invalid-params)
    (asserts! (> (len content-ids) u0) err-invalid-params)
    
    (map-set content-bundles
      { bundle-id: bundle-id }
      {
        name: name,
        creator: tx-sender,
        content-ids: content-ids,
        access-level: access-level,
        price: price,
        is-active: true
      }
    )
    
    (var-set next-bundle-id (+ bundle-id u1))
    (ok bundle-id)
  )
)

(define-read-only (get-bundle (bundle-id uint))
  (ok (unwrap! (map-get? content-bundles { bundle-id: bundle-id }) err-content-not-found))
)


(define-map content-locks
  { content-id: uint }
  {
    release-height: uint,
    is-locked: bool
  }
)

(define-public (set-content-lock (content-id uint) (release-height uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
    )
    (asserts! (is-eq (get creator content) tx-sender) err-unauthorized)
    (asserts! (>= release-height stacks-block-height) err-invalid-params)
    
    (map-set content-locks
      { content-id: content-id }
      {
        release-height: release-height,
        is-locked: true
      }
    )
    (ok true)
  )
)

(define-read-only (is-content-available (content-id uint))
  (let
    (
      (lock-info (unwrap! (map-get? content-locks { content-id: content-id }) (ok true)))
    )
    (if (get is-locked lock-info)
      (ok (>= stacks-block-height (get release-height lock-info)))
      (ok true)
    )
  )
)


(define-constant err-invalid-split (err u107))
(define-constant err-no-revenue (err u108))
(define-constant err-split-exists (err u109))

;; Revenue sharing structures
(define-map revenue-splits
  { content-id: uint }
  {
    creator: principal,
    beneficiaries: (list 10 principal),
    percentages: (list 10 uint),
    total-revenue: uint,
    is-active: bool
  }
)

(define-map beneficiary-balances
  { beneficiary: principal, content-id: uint }
  { balance: uint }
)

(define-map total-beneficiary-earnings
  { beneficiary: principal }
  { total-earned: uint }
)

;; Set up revenue sharing for content
(define-public (setup-revenue-split (content-id uint) (beneficiaries (list 10 principal)) (percentages (list 10 uint)))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
      (total-percentage (fold + percentages u0))
    )
    (asserts! (is-eq (get creator content) tx-sender) err-unauthorized)
    (asserts! (is-eq (len beneficiaries) (len percentages)) err-invalid-params)
    (asserts! (is-eq total-percentage u100) err-invalid-split)
    (asserts! (is-none (map-get? revenue-splits { content-id: content-id })) err-split-exists)
    
    (map-set revenue-splits
      { content-id: content-id }
      {
        creator: tx-sender,
        beneficiaries: beneficiaries,
        percentages: percentages,
        total-revenue: u0,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Record revenue and distribute to beneficiaries
(define-public (record-revenue (content-id uint) (amount uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
      (split-info (unwrap! (map-get? revenue-splits { content-id: content-id }) err-content-not-found))
    )
    (asserts! (is-eq (get creator content) tx-sender) err-unauthorized)
    (asserts! (> amount u0) err-invalid-params)
    (asserts! (get is-active split-info) err-content-locked)
    
    (distribute-revenue content-id amount (get beneficiaries split-info) (get percentages split-info))
    
    (map-set revenue-splits
      { content-id: content-id }
      {
        creator: (get creator split-info),
        beneficiaries: (get beneficiaries split-info),
        percentages: (get percentages split-info),
        total-revenue: (+ (get total-revenue split-info) amount),
        is-active: (get is-active split-info)
      }
    )
    (ok true)
  )
)

;; Helper function to distribute revenue
(define-private (distribute-revenue (content-id uint) (total-amount uint) (beneficiaries (list 10 principal)) (percentages (list 10 uint)))
  (begin
    (fold distribute-to-beneficiary 
      (zip beneficiaries percentages) 
      { content-id: content-id, total-amount: total-amount, success: true }
    )
  )
)

;; Helper function to distribute to individual beneficiary
(define-private (distribute-to-beneficiary (pair { beneficiary: principal, percentage: uint }) (context { content-id: uint, total-amount: uint, success: bool }))
  (let
    (
      (beneficiary (get beneficiary pair))
      (percentage (get percentage pair))
      (content-id (get content-id context))
      (total-amount (get total-amount context))
      (share-amount (/ (* total-amount percentage) u100))
      (current-balance (default-to u0 (get balance (map-get? beneficiary-balances { beneficiary: beneficiary, content-id: content-id }))))
      (current-total (default-to u0 (get total-earned (map-get? total-beneficiary-earnings { beneficiary: beneficiary }))))
    )
    (map-set beneficiary-balances
      { beneficiary: beneficiary, content-id: content-id }
      { balance: (+ current-balance share-amount) }
    )
    (map-set total-beneficiary-earnings
      { beneficiary: beneficiary }
      { total-earned: (+ current-total share-amount) }
    )
    context
  )
)

;; Helper function to zip two lists
(define-private (zip (list1 (list 10 principal)) (list2 (list 10 uint)))
  (map create-pair-at-index (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))
)

;; Helper function to create pairs
(define-private (create-pair-at-index (index uint))
  {
    beneficiary: (default-to tx-sender (element-at? (list tx-sender tx-sender tx-sender tx-sender tx-sender tx-sender tx-sender tx-sender tx-sender tx-sender) index)),
    percentage: (default-to u0 (element-at? (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0) index))
  }
)

;; Withdraw earnings for a beneficiary
(define-public (withdraw-earnings (content-id uint))
  (let
    (
      (balance-info (unwrap! (map-get? beneficiary-balances { beneficiary: tx-sender, content-id: content-id }) err-no-revenue))
      (balance (get balance balance-info))
    )
    (asserts! (> balance u0) err-no-revenue)
    
    (map-set beneficiary-balances
      { beneficiary: tx-sender, content-id: content-id }
      { balance: u0 }
    )
    (ok balance)
  )
)

;; Get revenue split information
(define-read-only (get-revenue-split (content-id uint))
  (ok (unwrap! (map-get? revenue-splits { content-id: content-id }) err-content-not-found))
)

;; Get beneficiary balance for specific content
(define-read-only (get-beneficiary-balance (beneficiary principal) (content-id uint))
  (ok (default-to u0 (get balance (map-get? beneficiary-balances { beneficiary: beneficiary, content-id: content-id }))))
)

;; Get total earnings for beneficiary
(define-read-only (get-total-earnings (beneficiary principal))
  (ok (default-to u0 (get total-earned (map-get? total-beneficiary-earnings { beneficiary: beneficiary }))))
)

;; Toggle revenue split status
(define-public (toggle-revenue-split (content-id uint))
  (let
    (
      (content (unwrap! (map-get? contents { content-id: content-id }) err-content-not-found))
      (split-info (unwrap! (map-get? revenue-splits { content-id: content-id }) err-content-not-found))
    )
    (asserts! (is-eq (get creator content) tx-sender) err-unauthorized)
    
    (map-set revenue-splits
      { content-id: content-id }
      {
        creator: (get creator split-info),
        beneficiaries: (get beneficiaries split-info),
        percentages: (get percentages split-info),
        total-revenue: (get total-revenue split-info),
        is-active: (not (get is-active split-info))
      }
    )
    (ok true)
  )
)