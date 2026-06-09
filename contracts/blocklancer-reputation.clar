;; BlockLancer Reputation System Contract
;; @version clarity-4
;; Tracks user reliability scores based on completed escrows and dispute outcomes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u600))
(define-constant err-not-authorized (err u601))
(define-constant err-invalid-score (err u602))

(define-constant initial-score u500)
(define-constant max-score u1000)
(define-constant min-score u0)

;; Score adjustments
(define-constant escrow-complete-client-bonus u20)
(define-constant escrow-complete-freelancer-bonus u25)
(define-constant dispute-winner-bonus u5)
(define-constant dispute-loser-penalty u30)
(define-constant on-time-bonus u10)
(define-constant late-penalty u5)

;; Authorized callers
(define-data-var escrow-contract-principal (optional principal) none)
(define-data-var dispute-contract-principal (optional principal) none)

;; Pause
(define-data-var contract-paused bool false)
(define-private (assert-not-paused) (ok (asserts! (not (var-get contract-paused)) (err u999))))

;; User reputation map
(define-map user-reputation
  principal
  {
    score: uint,
    completed-escrows: uint,
    cancelled-escrows: uint,
    disputes-opened: uint,
    disputes-won: uint,
    disputes-lost: uint,
    on-time-completions: uint,
    late-completions: uint,
    total-volume: uint,
    last-updated: uint
  }
)

;; Private helper to get or create default reputation
(define-private (get-or-default-reputation (user principal))
  (default-to {
    score: initial-score,
    completed-escrows: u0,
    cancelled-escrows: u0,
    disputes-opened: u0,
    disputes-won: u0,
    disputes-lost: u0,
    on-time-completions: u0,
    late-completions: u0,
    total-volume: u0,
    last-updated: u0
  } (map-get? user-reputation user))
)

;; Safe add: cap at max-score
(define-private (safe-add-score (current uint) (bonus uint))
  (if (> (+ current bonus) max-score)
    max-score
    (+ current bonus)
  )
)

;; Safe subtract: floor at min-score
(define-private (safe-sub-score (current uint) (penalty uint))
  (if (< current penalty)
    min-score
    (- current penalty)
  )
)

;; Admin functions
(define-public (set-escrow-contract (escrow principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set escrow-contract-principal (some escrow))
    (ok true)
  )
)

(define-public (set-dispute-contract (dispute principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set dispute-contract-principal (some dispute))
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused paused)
    (ok true)
  )
)

;; Authorization check - only escrow or dispute contracts can call record functions
(define-private (is-authorized-caller)
  (or
    (is-eq (some tx-sender) (var-get escrow-contract-principal))
    (is-eq (some tx-sender) (var-get dispute-contract-principal))
    (is-eq tx-sender contract-owner)
  )
)

;; Record escrow completion - called when an escrow completes successfully
(define-public (record-escrow-completion (client principal) (freelancer principal) (amount uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-authorized-caller) err-not-authorized)

    (let (
      (client-rep (get-or-default-reputation client))
      (freelancer-rep (get-or-default-reputation freelancer))
    )
      ;; Update client reputation
      (map-set user-reputation client
        (merge client-rep {
          score: (safe-add-score (get score client-rep) escrow-complete-client-bonus),
          completed-escrows: (+ (get completed-escrows client-rep) u1),
          total-volume: (+ (get total-volume client-rep) amount),
          last-updated: stacks-block-height
        })
      )

      ;; Update freelancer reputation
      (map-set user-reputation freelancer
        (merge freelancer-rep {
          score: (safe-add-score (get score freelancer-rep) escrow-complete-freelancer-bonus),
          completed-escrows: (+ (get completed-escrows freelancer-rep) u1),
          total-volume: (+ (get total-volume freelancer-rep) amount),
          last-updated: stacks-block-height
        })
      )
    )

    (ok true)
  )
)

;; Record dispute outcome
(define-public (record-dispute-outcome (winner principal) (loser principal) (resolution uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-authorized-caller) err-not-authorized)

    (let (
      (winner-rep (get-or-default-reputation winner))
      (loser-rep (get-or-default-reputation loser))
    )
      ;; Update winner
      (map-set user-reputation winner
        (merge winner-rep {
          score: (safe-add-score (get score winner-rep) dispute-winner-bonus),
          disputes-won: (+ (get disputes-won winner-rep) u1),
          last-updated: stacks-block-height
        })
      )

      ;; Update loser
      (map-set user-reputation loser
        (merge loser-rep {
          score: (safe-sub-score (get score loser-rep) dispute-loser-penalty),
          disputes-lost: (+ (get disputes-lost loser-rep) u1),
          last-updated: stacks-block-height
        })
      )
    )

    (ok true)
  )
)

;; Record dispute opened
(define-public (record-dispute-opened (user principal))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-authorized-caller) err-not-authorized)

    (let ((rep (get-or-default-reputation user)))
      (map-set user-reputation user
        (merge rep {
          disputes-opened: (+ (get disputes-opened rep) u1),
          last-updated: stacks-block-height
        })
      )
    )

    (ok true)
  )
)

;; Record on-time completion
(define-public (record-on-time-completion (user principal))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-authorized-caller) err-not-authorized)

    (let ((rep (get-or-default-reputation user)))
      (map-set user-reputation user
        (merge rep {
          score: (safe-add-score (get score rep) on-time-bonus),
          on-time-completions: (+ (get on-time-completions rep) u1),
          last-updated: stacks-block-height
        })
      )
    )

    (ok true)
  )
)

;; Record late completion
(define-public (record-late-completion (user principal))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-authorized-caller) err-not-authorized)

    (let ((rep (get-or-default-reputation user)))
      (map-set user-reputation user
        (merge rep {
          score: (safe-sub-score (get score rep) late-penalty),
          late-completions: (+ (get late-completions rep) u1),
          last-updated: stacks-block-height
        })
      )
    )

    (ok true)
  )
)

;; Record cancelled escrow
(define-public (record-escrow-cancellation (user principal))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-authorized-caller) err-not-authorized)

    (let ((rep (get-or-default-reputation user)))
      (map-set user-reputation user
        (merge rep {
          cancelled-escrows: (+ (get cancelled-escrows rep) u1),
          last-updated: stacks-block-height
        })
      )
    )

    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-reputation (user principal))
  (get-or-default-reputation user)
)

(define-read-only (get-score (user principal))
  (get score (get-or-default-reputation user))
)

(define-read-only (is-paused-status) (var-get contract-paused))
