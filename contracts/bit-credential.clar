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