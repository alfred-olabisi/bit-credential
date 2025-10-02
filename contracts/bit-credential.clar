;; Title: BitCredential - Trustless Skills & Certification Registry
;;
;; Summary:
;; BitCredential establishes a decentralized framework for issuing, verifying, and managing 
;; professional certifications on Bitcoin's Layer 2. The protocol enables educational institutions,
;; corporations, and professional bodies to mint verifiable credentials while maintaining full
;; transparency and immutability through Stacks blockchain technology.
;;
;; Description:
;; This smart contract implements a comprehensive certification ecosystem where authorized issuers
;; can create tamper-proof digital credentials for skill validation. Each credential is tracked
;; as an on-chain asset with embedded metadata including skill level, expiration, and verification
;; status. The platform features a marketplace for credential verification services, reputation
;; scoring for issuers, and portfolio analytics for credential holders. Built with Bitcoin's
;; security model, BitCredential ensures permanent, auditable records of professional achievements
;; that can be easily verified by employers, educational institutions, and regulatory bodies
;; without centralized intermediaries.

;; CONSTANTS

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-credential-not-found (err u102))
(define-constant err-invalid-parameter (err u103))
(define-constant err-already-verified (err u104))
(define-constant err-not-verified (err u105))
(define-constant err-expired-credential (err u106))
(define-constant err-insufficient-funds (err u107))

;; DATA VARIABLES

(define-data-var total-credentials uint u0)
(define-data-var platform-fee uint u500000) ;; 0.5 STX in microSTX
(define-data-var total-platform-fees uint u0)
(define-data-var contract-paused bool false)
(define-data-var verification-counter uint u0)

;; DATA MAPS - CORE STRUCTURES

;; Credential NFT data structure
(define-map credentials
    uint
    {
        holder: principal,
        issuer: principal,
        skill-name: (string-utf8 64),
        skill-category: (string-utf8 32),
        certification-level: uint, ;; 1=Basic, 2=Intermediate, 3=Advanced, 4=Expert
        issue-date: uint,
        expiry-date: uint,
        verified: bool,
        metadata-uri: (string-utf8 256),
        revoked: bool,
    }
)

;; Issuer authorization and reputation
(define-map authorized-issuers
    principal
    {
        name: (string-utf8 128),
        issuer-type: uint, ;; 1=Educational, 2=Corporate, 3=Professional Body
        verified: bool,
        credentials-issued: uint,
        reputation-score: uint,
    }
)

;; Skill category definitions
(define-map skill-categories
    (string-utf8 32)
    {
        active: bool,
        total-credentials: uint,
        category-description: (string-utf8 128),
    }
)

;; Holder profiles
(define-map holder-profiles
    principal
    {
        total-credentials: uint,
        verified-credentials: uint,
        skill-points: uint,
        profile-active: bool,
    }
)

;; DATA MAPS - MARKETPLACE & ANALYTICS

;; Marketplace for credential verification services
(define-map verification-requests
    uint
    {
        requester: principal,
        credential-holder: principal,
        credential-id: uint,
        verification-fee: uint,
        request-timestamp: uint,
        completed: bool,
        verified: bool,
    }
)

;; Credential marketplace listings
(define-map credential-listings
    {
        credential-id: uint,
        holder: principal,
    }
    {
        verification-price: uint,
        available: bool,
        listed-at: uint,
    }
)

;; Analytics and reputation tracking
(define-map issuer-analytics
    principal
    {
        monthly-credentials: uint,
        revocation-rate: uint,
        average-validity-period: uint,
        last-updated: uint,
    }
)

;; READ-ONLY FUNCTIONS - CORE DATA RETRIEVAL

(define-read-only (get-credential-details (credential-id uint))
    (map-get? credentials credential-id)
)

(define-read-only (get-issuer-info (issuer principal))
    (map-get? authorized-issuers issuer)
)

(define-read-only (get-holder-profile (holder principal))
    (map-get? holder-profiles holder)
)

(define-read-only (get-skill-category (category (string-utf8 32)))
    (map-get? skill-categories category)
)

(define-read-only (get-total-credentials)
    (var-get total-credentials)
)

(define-read-only (is-credential-valid (credential-id uint))
    (let ((credential (unwrap! (map-get? credentials credential-id) (err u0))))
        (ok (and
            (get verified credential)
            (not (get revoked credential))
            (> (get expiry-date credential) stacks-block-height)
        ))
    )
)

;; READ-ONLY FUNCTIONS - MARKETPLACE & ANALYTICS

(define-read-only (get-verification-request (verification-id uint))
    (map-get? verification-requests verification-id)
)

(define-read-only (get-credential-listing
        (credential-id uint)
        (holder principal)
    )
    (map-get? credential-listings {
        credential-id: credential-id,
        holder: holder,
    })
)

(define-read-only (get-issuer-analytics (issuer principal))
    (map-get? issuer-analytics issuer)
)

(define-read-only (get-holder-skill-summary (holder principal))
    (let ((profile (unwrap! (map-get? holder-profiles holder) (err u0))))
        (ok {
            total-credentials: (get total-credentials profile),
            verified-credentials: (get verified-credentials profile),
            skill-points: (get skill-points profile),
            verification-rate: (if (> (get total-credentials profile) u0)
                (/ (* (get verified-credentials profile) u100)
                    (get total-credentials profile)
                )
                u0
            ),
        })
    )
)

(define-read-only (calculate-credential-trust-score (credential-id uint))
    (let ((credential (unwrap! (map-get? credentials credential-id) (err u0))))
        (let (
                (issuer-info (unwrap! (map-get? authorized-issuers (get issuer credential))
                    (err u0)
                ))
                (is-valid (unwrap! (is-credential-valid credential-id) (err u0)))
                (time-factor (if (> (get expiry-date credential) stacks-block-height)
                    u100
                    u0
                ))
            )
            (ok (+ (* (get reputation-score issuer-info) u10)
                (if is-valid u300 u0)
                time-factor
                (* (get certification-level credential) u50)
            ))
        )
    )
)

;; PRIVATE FUNCTIONS

(define-private (calculate-skill-points (level uint))
    (if (is-eq level u1)
        u10 ;; Basic: 10 points
        (if (is-eq level u2)
            u25 ;; Intermediate: 25 points
            (if (is-eq level u3)
                u50 ;; Advanced: 50 points
                (if (is-eq level u4)
                    u100 ;; Expert: 100 points
                    u0
                )
            )
        )
    )
)

(define-private (verify-single-credential (credential-id uint))
    (match (map-get? credentials credential-id)
        credential (map-set credentials credential-id (merge credential { verified: true }))
        false
    )
)

;; PUBLIC FUNCTIONS - ISSUER MANAGEMENT

(define-public (register-issuer
        (name (string-utf8 128))
        (issuer-type uint)
    )
    (begin
        (asserts! (not (var-get contract-paused)) err-invalid-parameter)
        (asserts! (and (>= issuer-type u1) (<= issuer-type u3))
            err-invalid-parameter
        )
        (asserts! (is-none (map-get? authorized-issuers tx-sender))
            err-invalid-parameter
        )
        (map-set authorized-issuers tx-sender {
            name: name,
            issuer-type: issuer-type,
            verified: false,
            credentials-issued: u0,
            reputation-score: u0,
        })
        (ok true)
    )
)

(define-public (verify-issuer (issuer principal))
    (let ((issuer-info (unwrap! (map-get? authorized-issuers issuer) err-not-authorized)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (asserts! (not (get verified issuer-info)) err-already-verified)
            (map-set authorized-issuers issuer
                (merge issuer-info { verified: true })
            )
            (ok true)
        )
    )
)

(define-public (add-skill-category
        (category (string-utf8 32))
        (description (string-utf8 128))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? skill-categories category))
            err-invalid-parameter
        )
        (map-set skill-categories category {
            active: true,
            total-credentials: u0,
            category-description: description,
        })
        (ok true)
    )
)

;; PUBLIC FUNCTIONS - ADMINISTRATIVE

(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u5000000) err-invalid-parameter) ;; Max 5 STX
        (var-set platform-fee new-fee)
        (ok true)
    )
)

(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok true)
    )
)

(define-public (withdraw-platform-fees)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let ((fees (var-get total-platform-fees)))
            (var-set total-platform-fees u0)
            (stx-transfer? fees tx-sender contract-owner)
        )
    )
)

(define-public (deactivate-skill-category (category (string-utf8 32)))
    (let ((category-info (unwrap! (map-get? skill-categories category) err-invalid-parameter)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (map-set skill-categories category
                (merge category-info { active: false })
            )
            (ok true)
        )
    )
)

(define-public (emergency-revoke-credential (credential-id uint))
    (let ((credential (unwrap! (map-get? credentials credential-id) err-credential-not-found)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-owner-only)
            (map-set credentials credential-id
                (merge credential { revoked: true })
            )
            (ok true)
        )
    )
)

;; PUBLIC FUNCTIONS - CREDENTIAL MINTING

(define-public (mint-credential
        (holder principal)
        (skill-name (string-utf8 64))
        (skill-category (string-utf8 32))
        (certification-level uint)
        (validity-duration uint)
        (metadata-uri (string-utf8 256))
    )
    (let (
            (credential-id (+ (var-get total-credentials) u1))
            (issuer-info (unwrap! (map-get? authorized-issuers tx-sender) err-not-authorized))
            (category-info (unwrap! (map-get? skill-categories skill-category)
                err-invalid-parameter
            ))
            (holder-profile (default-to {
                total-credentials: u0,
                verified-credentials: u0,
                skill-points: u0,
                profile-active: false,
            }
                (map-get? holder-profiles holder)
            ))
            (skill-points (calculate-skill-points certification-level))
        )