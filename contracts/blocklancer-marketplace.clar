;; BlockLancer Job Marketplace Contract
;; @version clarity-4
;; Allows clients to post jobs and freelancers to apply

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u700))
(define-constant err-not-authorized (err u701))
(define-constant err-invalid-state (err u702))
(define-constant err-job-not-found (err u703))
(define-constant err-already-applied (err u704))
(define-constant err-application-not-found (err u705))
(define-constant err-invalid-budget (err u706))

;; Job Status Constants
(define-constant job-open u0)
(define-constant job-filled u1)
(define-constant job-cancelled u2)

;; Application Status Constants
(define-constant application-pending u0)
(define-constant application-accepted u1)
(define-constant application-rejected u2)

;; Pause
(define-data-var contract-paused bool false)
(define-private (assert-not-paused) (ok (asserts! (not (var-get contract-paused)) (err u999))))

;; Data Variables
(define-data-var next-job-id uint u1)

;; Data Maps
(define-map jobs
  uint
  {
    poster: principal,
    title: (string-utf8 200),
    description: (string-utf8 500),
    budget-min: uint,
    budget-max: uint,
    deadline: uint,
    status: uint,
    skills: (string-utf8 200),
    created-at: uint,
    escrow-id: (optional uint),
    application-count: uint
  }
)

(define-map job-applications
  {job-id: uint, applicant: principal}
  {
    cover-letter: (string-utf8 500),
    proposed-amount: uint,
    proposed-timeline: uint,
    status: uint,
    applied-at: uint
  }
)

;; Track application count per job (already in jobs map)

;; Admin
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused paused)
    (ok true)
  )
)

;; Post a new job
(define-public (post-job
    (title (string-utf8 200))
    (description (string-utf8 500))
    (budget-min uint)
    (budget-max uint)
    (deadline uint)
    (skills (string-utf8 200)))
  (let
    (
      (job-id (var-get next-job-id))
      (current-time stacks-block-height)
    )
    (try! (assert-not-paused))
    (asserts! (> budget-max u0) err-invalid-budget)
    (asserts! (>= budget-max budget-min) err-invalid-budget)
    (asserts! (> deadline current-time) err-invalid-state)

    (map-set jobs job-id
      {
        poster: tx-sender,
        title: title,
        description: description,
        budget-min: budget-min,
        budget-max: budget-max,
        deadline: deadline,
        status: job-open,
        skills: skills,
        created-at: current-time,
        escrow-id: none,
        application-count: u0
      }
    )

    (var-set next-job-id (+ job-id u1))

    (ok job-id)
  )
)

;; Apply to a job
(define-public (apply-to-job
    (job-id uint)
    (cover-letter (string-utf8 500))
    (proposed-amount uint)
    (proposed-timeline uint))
  (let
    (
      (job-data (unwrap! (map-get? jobs job-id) err-job-not-found))
      (current-time stacks-block-height)
      (app-key {job-id: job-id, applicant: tx-sender})
    )
    (try! (assert-not-paused))
    ;; Job must be open
    (asserts! (is-eq (get status job-data) job-open) err-invalid-state)
    ;; Can't apply to own job
    (asserts! (not (is-eq tx-sender (get poster job-data))) err-not-authorized)
    ;; Can't apply twice
    (asserts! (is-none (map-get? job-applications app-key)) err-already-applied)
    ;; Proposed amount must be within budget
    (asserts! (> proposed-amount u0) err-invalid-budget)

    (map-set job-applications app-key
      {
        cover-letter: cover-letter,
        proposed-amount: proposed-amount,
        proposed-timeline: proposed-timeline,
        status: application-pending,
        applied-at: current-time
      }
    )

    ;; Increment application count
    (map-set jobs job-id
      (merge job-data {application-count: (+ (get application-count job-data) u1)})
    )

    (ok true)
  )
)

;; Accept an application (job poster only)
(define-public (accept-application
    (job-id uint)
    (applicant principal))
  (let
    (
      (job-data (unwrap! (map-get? jobs job-id) err-job-not-found))
      (app-key {job-id: job-id, applicant: applicant})
      (app-data (unwrap! (map-get? job-applications app-key) err-application-not-found))
    )
    (try! (assert-not-paused))
    ;; Only poster can accept
    (asserts! (is-eq tx-sender (get poster job-data)) err-not-authorized)
    ;; Job must be open
    (asserts! (is-eq (get status job-data) job-open) err-invalid-state)
    ;; Application must be pending
    (asserts! (is-eq (get status app-data) application-pending) err-invalid-state)

    ;; Mark application as accepted
    (map-set job-applications app-key
      (merge app-data {status: application-accepted})
    )

    ;; Mark job as filled
    (map-set jobs job-id
      (merge job-data {status: job-filled})
    )

    (ok true)
  )
)

;; Reject an application (job poster only)
(define-public (reject-application
    (job-id uint)
    (applicant principal))
  (let
    (
      (job-data (unwrap! (map-get? jobs job-id) err-job-not-found))
      (app-key {job-id: job-id, applicant: applicant})
      (app-data (unwrap! (map-get? job-applications app-key) err-application-not-found))
    )
    (try! (assert-not-paused))
    (asserts! (is-eq tx-sender (get poster job-data)) err-not-authorized)
    (asserts! (is-eq (get status app-data) application-pending) err-invalid-state)

    (map-set job-applications app-key
      (merge app-data {status: application-rejected})
    )

    (ok true)
  )
)

;; Link an escrow to a job (poster only, after creating escrow separately)
(define-public (link-escrow-to-job
    (job-id uint)
    (escrow-id uint))
  (let
    (
      (job-data (unwrap! (map-get? jobs job-id) err-job-not-found))
    )
    (try! (assert-not-paused))
    (asserts! (is-eq tx-sender (get poster job-data)) err-not-authorized)
    (asserts! (is-eq (get status job-data) job-filled) err-invalid-state)

    (map-set jobs job-id
      (merge job-data {escrow-id: (some escrow-id)})
    )

    (ok true)
  )
)

;; Cancel a job (poster only)
(define-public (cancel-job (job-id uint))
  (let
    (
      (job-data (unwrap! (map-get? jobs job-id) err-job-not-found))
    )
    (try! (assert-not-paused))
    (asserts! (is-eq tx-sender (get poster job-data)) err-not-authorized)
    (asserts! (is-eq (get status job-data) job-open) err-invalid-state)

    (map-set jobs job-id
      (merge job-data {status: job-cancelled})
    )

    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-job (job-id uint))
  (map-get? jobs job-id)
)

(define-read-only (get-application (job-id uint) (applicant principal))
  (map-get? job-applications {job-id: job-id, applicant: applicant})
)

(define-read-only (get-job-count)
  (- (var-get next-job-id) u1)
)

(define-read-only (is-paused) (var-get contract-paused))
