(define-data-var next-poll-id uint u0)
(define-data-var platform-fee uint u100000)
(define-data-var admin principal tx-sender)

(define-map polls
    { poll-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        start-block: uint,
        end-block: uint,
        min-vote-threshold: uint,
        is-active: bool,
        total-votes: uint,
        winning-option: (optional uint),
        option-count: uint,
    }
)

(define-map poll-options
    {
        poll-id: uint,
        option-id: uint,
    }
    {
        text: (string-ascii 200),
        vote-count: uint,
    }
)

(define-map votes
    {
        poll-id: uint,
        voter: principal,
    }
    {
        option-id: uint,
        block-height: uint,
        weight: uint,
    }
)

(define-map voter-registration
    { voter: principal }
    {
        reputation: uint,
        total-votes-cast: uint,
        registration-block: uint,
    }
)

(define-map poll-delegates
    {
        poll-id: uint,
        delegator: principal,
    }
    {
        delegate: principal,
        weight: uint,
    }
)

(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-POLL-NOT-FOUND (err u1002))
(define-constant ERR-POLL-ENDED (err u1003))
(define-constant ERR-POLL-NOT-STARTED (err u1004))
(define-constant ERR-ALREADY-VOTED (err u1005))
(define-constant ERR-INVALID-OPTION (err u1006))
(define-constant ERR-INSUFFICIENT-THRESHOLD (err u1007))
(define-constant ERR-POLL-STILL-ACTIVE (err u1008))
(define-constant ERR-VOTER-NOT-REGISTERED (err u1009))
(define-constant ERR-INVALID-DELEGATE (err u1010))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1011))
(define-constant ERR-TOO-MANY-OPTIONS (err u1012))

(define-public (register-voter)
    (let ((current-block stacks-block-height))
        (map-set voter-registration { voter: tx-sender } {
            reputation: u100,
            total-votes-cast: u0,
            registration-block: current-block,
        })
        (ok true)
    )
)

(define-public (create-poll
        (title (string-ascii 100))
        (description (string-ascii 500))
        (option1 (string-ascii 200))
        (option2 (string-ascii 200))
        (option3 (optional (string-ascii 200)))
        (option4 (optional (string-ascii 200)))
        (duration uint)
        (min-threshold uint)
    )
    (let (
            (poll-id (var-get next-poll-id))
            (current-block stacks-block-height)
            (end-block (+ current-block duration))
        )
        (asserts! (>= (stx-get-balance tx-sender) (var-get platform-fee))
            ERR-INSUFFICIENT-FUNDS
        )
        (try! (stx-transfer? (var-get platform-fee) tx-sender (var-get admin)))

        (map-set polls { poll-id: poll-id } {
            title: title,
            description: description,
            creator: tx-sender,
            start-block: current-block,
            end-block: end-block,
            min-vote-threshold: min-threshold,
            is-active: true,
            total-votes: u0,
            winning-option: none,
            option-count: (+ u2
                (if (is-some option3)
                    u1
                    u0
                )
                (if (is-some option4)
                    u1
                    u0
                )),
        })

        (map-set poll-options {
            poll-id: poll-id,
            option-id: u0,
        } {
            text: option1,
            vote-count: u0,
        })
        (map-set poll-options {
            poll-id: poll-id,
            option-id: u1,
        } {
            text: option2,
            vote-count: u0,
        })

        (if (is-some option3)
            (map-set poll-options {
                poll-id: poll-id,
                option-id: u2,
            } {
                text: (unwrap-panic option3),
                vote-count: u0,
            })
            true
        )

        (if (is-some option4)
            (map-set poll-options {
                poll-id: poll-id,
                option-id: u3,
            } {
                text: (unwrap-panic option4),
                vote-count: u0,
            })
            true
        )

        (var-set next-poll-id (+ poll-id u1))
        (ok poll-id)
    )
)

(define-public (cast-vote
        (poll-id uint)
        (option-id uint)
    )
    (let (
            (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-POLL-NOT-FOUND))
            (current-block stacks-block-height)
            (voter-info (unwrap! (map-get? voter-registration { voter: tx-sender })
                ERR-VOTER-NOT-REGISTERED
            ))
            (vote-weight (calculate-vote-weight tx-sender))
            (existing-vote (map-get? votes {
                poll-id: poll-id,
                voter: tx-sender,
            }))
        )
        (asserts! (get is-active poll) ERR-POLL-ENDED)
        (asserts! (>= current-block (get start-block poll)) ERR-POLL-NOT-STARTED)
        (asserts! (< current-block (get end-block poll)) ERR-POLL-ENDED)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
        (asserts! (< option-id (get option-count poll)) ERR-INVALID-OPTION)
        (asserts!
            (is-some (map-get? poll-options {
                poll-id: poll-id,
                option-id: option-id,
            }))
            ERR-INVALID-OPTION
        )

        (map-set votes {
            poll-id: poll-id,
            voter: tx-sender,
        } {
            option-id: option-id,
            block-height: current-block,
            weight: vote-weight,
        })

        (update-option-count poll-id option-id vote-weight)
        (update-poll-total-votes poll-id vote-weight)
        (update-voter-stats tx-sender)
        (ok true)
    )
)

(define-public (delegate-vote
        (poll-id uint)
        (delegate principal)
        (weight uint)
    )
    (let (
            (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-POLL-NOT-FOUND))
            (current-block stacks-block-height)
            (delegator-info (unwrap! (map-get? voter-registration { voter: tx-sender })
                ERR-VOTER-NOT-REGISTERED
            ))
            (delegate-info (unwrap! (map-get? voter-registration { voter: delegate })
                ERR-INVALID-DELEGATE
            ))
        )
        (asserts! (get is-active poll) ERR-POLL-ENDED)
        (asserts! (>= current-block (get start-block poll)) ERR-POLL-NOT-STARTED)
        (asserts! (< current-block (get end-block poll)) ERR-POLL-ENDED)
        (asserts! (not (is-eq tx-sender delegate)) ERR-INVALID-DELEGATE)

        (map-set poll-delegates {
            poll-id: poll-id,
            delegator: tx-sender,
        } {
            delegate: delegate,
            weight: weight,
        })
        (ok true)
    )
)

(define-public (finalize-poll (poll-id uint))
    (let (
            (poll (unwrap! (map-get? polls { poll-id: poll-id }) ERR-POLL-NOT-FOUND))
            (current-block stacks-block-height)
        )
        (asserts! (>= current-block (get end-block poll)) ERR-POLL-STILL-ACTIVE)
        (asserts! (>= (get total-votes poll) (get min-vote-threshold poll))
            ERR-INSUFFICIENT-THRESHOLD
        )

        (let ((winning-option-id (find-winning-option poll-id (get option-count poll))))
            (map-set polls { poll-id: poll-id }
                (merge poll {
                    is-active: false,
                    winning-option: (some winning-option-id),
                })
            )
            (ok winning-option-id)
        )
    )
)

(define-private (calculate-vote-weight (voter principal))
    (let (
            (voter-info (unwrap-panic (map-get? voter-registration { voter: voter })))
            (base-weight u1)
            (reputation-bonus (/ (get reputation voter-info) u100))
        )
        (+ base-weight reputation-bonus)
    )
)

(define-private (update-option-count
        (poll-id uint)
        (option-id uint)
        (weight uint)
    )
    (let ((option (unwrap-panic (map-get? poll-options {
            poll-id: poll-id,
            option-id: option-id,
        }))))
        (map-set poll-options {
            poll-id: poll-id,
            option-id: option-id,
        }
            (merge option { vote-count: (+ (get vote-count option) weight) })
        )
    )
)

(define-private (update-poll-total-votes
        (poll-id uint)
        (weight uint)
    )
    (let ((poll (unwrap-panic (map-get? polls { poll-id: poll-id }))))
        (map-set polls { poll-id: poll-id }
            (merge poll { total-votes: (+ (get total-votes poll) weight) })
        )
    )
)

(define-private (update-voter-stats (voter principal))
    (let ((voter-info (unwrap-panic (map-get? voter-registration { voter: voter }))))
        (map-set voter-registration { voter: voter }
            (merge voter-info {
                total-votes-cast: (+ (get total-votes-cast voter-info) u1),
                reputation: (+ (get reputation voter-info) u10),
            })
        )
    )
)

(define-private (find-winning-option
        (poll-id uint)
        (option-count uint)
    )
    (let (
            (option0-votes (default-to u0
                (get vote-count
                    (map-get? poll-options {
                        poll-id: poll-id,
                        option-id: u0,
                    })
                )))
            (option1-votes (default-to u0
                (get vote-count
                    (map-get? poll-options {
                        poll-id: poll-id,
                        option-id: u1,
                    })
                )))
            (option2-votes (if (> option-count u2)
                (default-to u0
                    (get vote-count
                        (map-get? poll-options {
                            poll-id: poll-id,
                            option-id: u2,
                        })
                    ))
                u0
            ))
            (option3-votes (if (> option-count u3)
                (default-to u0
                    (get vote-count
                        (map-get? poll-options {
                            poll-id: poll-id,
                            option-id: u3,
                        })
                    ))
                u0
            ))
        )
        (if (and
                (>= option0-votes option1-votes)
                (>= option0-votes option2-votes)
                (>= option0-votes option3-votes)
            )
            u0
            (if (and (>= option1-votes option2-votes) (>= option1-votes option3-votes))
                u1
                (if (>= option2-votes option3-votes)
                    u2
                    u3
                )
            )
        )
    )
)

(define-read-only (get-poll (poll-id uint))
    (map-get? polls { poll-id: poll-id })
)

(define-read-only (get-poll-option
        (poll-id uint)
        (option-id uint)
    )
    (map-get? poll-options {
        poll-id: poll-id,
        option-id: option-id,
    })
)

(define-read-only (get-vote
        (poll-id uint)
        (voter principal)
    )
    (map-get? votes {
        poll-id: poll-id,
        voter: voter,
    })
)

(define-read-only (get-voter-info (voter principal))
    (map-get? voter-registration { voter: voter })
)

(define-read-only (get-poll-results (poll-id uint))
    {
        poll-info: (map-get? polls { poll-id: poll-id }),
        option-0: (map-get? poll-options {
            poll-id: poll-id,
            option-id: u0,
        }),
        option-1: (map-get? poll-options {
            poll-id: poll-id,
            option-id: u1,
        }),
        option-2: (map-get? poll-options {
            poll-id: poll-id,
            option-id: u2,
        }),
        option-3: (map-get? poll-options {
            poll-id: poll-id,
            option-id: u3,
        }),
    }
)

(define-read-only (is-poll-active (poll-id uint))
    (match (map-get? polls { poll-id: poll-id })
        some-poll (and
            (get is-active some-poll)
            (>= stacks-block-height (get start-block some-poll))
            (< stacks-block-height (get end-block some-poll))
        )
        false
    )
)

(define-read-only (get-platform-fee)
    (var-get platform-fee)
)

(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (var-set platform-fee new-fee)
        (ok true)
    )
)

(define-public (transfer-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (var-set admin new-admin)
        (ok true)
    )
)
