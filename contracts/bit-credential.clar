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