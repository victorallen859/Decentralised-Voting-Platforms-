;; SPDX-License-Identifier: MIT
;; Voting Analytics Tracker - Independent analytics and insights contract
;; Clarity v3 - Statistical tracking and voter engagement metrics

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-INVALID-PERIOD (err u201))
(define-constant ERR-ANALYTICS-NOT-FOUND (err u202))
(define-constant ERR-ALREADY-TRACKED (err u203))
(define-constant ERR-INVALID-METRIC (err u204))
(define-constant ERR-INSUFFICIENT-DATA (err u205))

;; Data variables for tracking
(define-data-var contract-owner principal tx-sender)
(define-data-var analytics-fee uint u50000)
(define-data-var next-session-id uint u0)
(define-data-var total-tracked-votes uint u0)
(define-data-var analytics-enabled bool true)

;; Voting session tracking for detailed analytics
(define-map voting-sessions 
    { session-id: uint }
    {
        session-name: (string-ascii 100),
        creator: principal,
        start-block: uint,
        end-block: uint,
        total-participants: uint,
        total-votes: uint,
        average-participation: uint,
        is-active: bool
    }
)

;; Individual voter analytics within sessions
(define-map voter-session-stats
    { 
        session-id: uint,
        voter: principal 
    }
    {
        votes-cast: uint,
        first-vote-block: uint,
        last-vote-block: uint,
        participation-score: uint,
        voting-streak: uint
    }
)

;; Daily voting metrics aggregation
(define-map daily-metrics
    { day-block: uint }
    {
        unique-voters: uint,
        total-votes: uint,
        peak-voting-hour: uint,
        participation-rate: uint,
        new-voters: uint
    }
)

;; Voter engagement levels and historical tracking
(define-map voter-engagement
    { voter: principal }
    {
        total-sessions-participated: uint,
        lifetime-votes: uint,
        engagement-level: (string-ascii 20),
        last-activity-block: uint,
        consecutive-active-days: uint,
        highest-streak: uint
    }
)

;; Popular voting patterns and trends
(define-map voting-patterns
    { pattern-id: uint }
    {
        pattern-name: (string-ascii 50),
        description: (string-ascii 200),
        occurrence-count: uint,
        confidence-score: uint,
        identified-block: uint
    }
)

;; Leaderboard for most active voters
(define-map activity-leaderboard
    { rank: uint }
    {
        voter: principal,
        activity-score: uint,
        badges-earned: (list 10 (string-ascii 30)),
        last-updated: uint
    }
)

;; Create new voting analytics session
(define-public (create-analytics-session 
        (session-name (string-ascii 100))
        (duration uint)
    )
    (let (
            (session-id (var-get next-session-id))
            (current-block stacks-block-height)
            (end-block (+ current-block duration))
        )
        (asserts! (> (len session-name) u0) ERR-INVALID-PERIOD)
        (asserts! (> duration u100) ERR-INVALID-PERIOD)
        
        (map-set voting-sessions { session-id: session-id } {
            session-name: session-name,
            creator: tx-sender,
            start-block: current-block,
            end-block: end-block,
            total-participants: u0,
            total-votes: u0,
            average-participation: u0,
            is-active: true
        })
        
        (var-set next-session-id (+ session-id u1))
        (ok session-id)
    )
)

;; Track a vote in analytics system
(define-public (track-vote
        (session-id uint)
        (voter principal)
    )
    (let (
            (session (unwrap! (map-get? voting-sessions { session-id: session-id }) 
                              ERR-ANALYTICS-NOT-FOUND))
            (current-block stacks-block-height)
            (existing-stats (map-get? voter-session-stats { 
                session-id: session-id, 
                voter: voter 
            }))
        )
        (asserts! (get is-active session) ERR-INVALID-PERIOD)
        (asserts! (>= current-block (get start-block session)) ERR-INVALID-PERIOD)
        (asserts! (< current-block (get end-block session)) ERR-INVALID-PERIOD)
        
        ;; Update or create voter session stats
        (match existing-stats
            some-stats 
                (map-set voter-session-stats { session-id: session-id, voter: voter }
                    (merge some-stats {
                        votes-cast: (+ (get votes-cast some-stats) u1),
                        last-vote-block: current-block,
                        participation-score: (+ (get participation-score some-stats) u10),
                        voting-streak: (+ (get voting-streak some-stats) u1)
                    })
                )
            ;; Create new stats entry
            (map-set voter-session-stats { session-id: session-id, voter: voter } {
                votes-cast: u1,
                first-vote-block: current-block,
                last-vote-block: current-block,
                participation-score: u10,
                voting-streak: u1
            })
        )
        
        ;; Update session totals
        (update-session-totals session-id)
        
        ;; Update voter engagement
        (update-voter-engagement voter current-block)
        
        ;; Track daily metrics
        (update-daily-metrics current-block voter)
        
        ;; Increment total tracked votes
        (var-set total-tracked-votes (+ (var-get total-tracked-votes) u1))
        
        (ok true)
    )
)

;; Generate analytics insights for a session
(define-public (generate-session-insights (session-id uint))
    (let (
            (session (unwrap! (map-get? voting-sessions { session-id: session-id }) 
                              ERR-ANALYTICS-NOT-FOUND))
        )
        (asserts! (>= stacks-block-height (get end-block session)) ERR-INVALID-PERIOD)
        
        ;; Calculate final participation metrics
        (let (
                (total-votes (get total-votes session))
                (total-participants (get total-participants session))
                (avg-participation (if (> total-participants u0)
                                     (/ total-votes total-participants)
                                     u0))
            )
            ;; Update session with final insights
            (map-set voting-sessions { session-id: session-id }
                (merge session {
                    average-participation: avg-participation,
                    is-active: false
                })
            )
            
            (ok {
                session-id: session-id,
                total-votes: total-votes,
                total-participants: total-participants,
                average-participation: avg-participation,
                duration-blocks: (- (get end-block session) (get start-block session))
            })
        )
    )
)

;; Award engagement badges based on voting patterns
(define-public (award-engagement-badge 
        (voter principal)
        (badge-name (string-ascii 30))
    )
    (let (
            (engagement (unwrap! (map-get? voter-engagement { voter: voter }) 
                                ERR-ANALYTICS-NOT-FOUND))
            (current-badges (get badges-earned 
                               (default-to 
                                 { voter: voter, activity-score: u0, badges-earned: (list), last-updated: u0 }
                                 (map-get? activity-leaderboard { rank: u0 }))))
        )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (>= (get lifetime-votes engagement) u10) ERR-INSUFFICIENT-DATA)
        
        ;; Add badge if not already present
        (let ((updated-badges (unwrap! (as-max-len? (append current-badges badge-name) u10)
                                      ERR-INVALID-METRIC)))
            (update-leaderboard voter (get lifetime-votes engagement) updated-badges)
            (ok true)
        )
    )
)

;; Calculate voter engagement level based on activity
(define-private (calculate-engagement-level (lifetime-votes uint) (active-days uint))
    (if (and (>= lifetime-votes u100) (>= active-days u30))
        "Expert"
        (if (and (>= lifetime-votes u50) (>= active-days u15))
            "Advanced"
            (if (and (>= lifetime-votes u20) (>= active-days u7))
                "Intermediate"
                (if (>= lifetime-votes u5)
                    "Beginner"
                    "Novice"
                )
            )
        )
    )
)

;; Private helper functions
(define-private (update-session-totals (session-id uint))
    (let (
            (session (unwrap-panic (map-get? voting-sessions { session-id: session-id })))
        )
        (map-set voting-sessions { session-id: session-id }
            (merge session {
                total-votes: (+ (get total-votes session) u1)
            })
        )
    )
)

(define-private (update-voter-engagement (voter principal) (current-block uint))
    (let (
            (engagement (default-to 
                          { 
                            total-sessions-participated: u0,
                            lifetime-votes: u0,
                            engagement-level: "Novice",
                            last-activity-block: u0,
                            consecutive-active-days: u0,
                            highest-streak: u0
                          }
                          (map-get? voter-engagement { voter: voter })))
            (new-lifetime-votes (+ (get lifetime-votes engagement) u1))
            (new-engagement-level (calculate-engagement-level 
                                   new-lifetime-votes 
                                   (get consecutive-active-days engagement)))
        )
        (map-set voter-engagement { voter: voter }
            (merge engagement {
                lifetime-votes: new-lifetime-votes,
                engagement-level: new-engagement-level,
                last-activity-block: current-block
            })
        )
    )
)

(define-private (update-daily-metrics (current-block uint) (voter principal))
    (let (
            (day-block (/ current-block u144)) ;; Approximate daily blocks
            (daily-metric (default-to 
                            {
                              unique-voters: u0,
                              total-votes: u0,
                              peak-voting-hour: u0,
                              participation-rate: u0,
                              new-voters: u0
                            }
                            (map-get? daily-metrics { day-block: day-block })))
        )
        (map-set daily-metrics { day-block: day-block }
            (merge daily-metric {
                total-votes: (+ (get total-votes daily-metric) u1)
            })
        )
    )
)

(define-private (update-leaderboard 
        (voter principal) 
        (activity-score uint)
        (badges (list 10 (string-ascii 30)))
    )
    (map-set activity-leaderboard { rank: u0 } {
        voter: voter,
        activity-score: activity-score,
        badges-earned: badges,
        last-updated: stacks-block-height
    })
)

;; Read-only functions for analytics queries
(define-read-only (get-session-analytics (session-id uint))
    (map-get? voting-sessions { session-id: session-id })
)

(define-read-only (get-voter-session-stats (session-id uint) (voter principal))
    (map-get? voter-session-stats { session-id: session-id, voter: voter })
)

(define-read-only (get-voter-engagement (voter principal))
    (map-get? voter-engagement { voter: voter })
)

(define-read-only (get-daily-metrics (day-block uint))
    (map-get? daily-metrics { day-block: day-block })
)

(define-read-only (get-leaderboard-entry (rank uint))
    (map-get? activity-leaderboard { rank: rank })
)

(define-read-only (get-platform-analytics)
    (ok {
        total-tracked-votes: (var-get total-tracked-votes),
        total-sessions: (var-get next-session-id),
        analytics-enabled: (var-get analytics-enabled),
        current-block: stacks-block-height
    })
)

(define-read-only (calculate-participation-trend (session-id uint))
    (let (
            (session (map-get? voting-sessions { session-id: session-id }))
        )
        (match session
            some-session 
                (ok {
                    session-id: session-id,
                    participation-rate: (if (> (get total-participants some-session) u0)
                                          (/ (* (get total-votes some-session) u100) 
                                             (get total-participants some-session))
                                          u0),
                    engagement-score: (get average-participation some-session),
                    status: (if (get is-active some-session) "active" "completed")
                })
            ERR-ANALYTICS-NOT-FOUND
        )
    )
)

;; Admin functions
(define-public (update-analytics-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set analytics-fee new-fee)
        (ok true)
    )
)

(define-public (toggle-analytics (enabled bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set analytics-enabled enabled)
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)