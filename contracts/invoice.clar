
;; title: invoice
;; version:
;; summary: Smart contract to create and manage invoices
;; description: This contract allows users to create 2 types of invoices:
;;              - A standard invoice: Can be paid in full only by a specific user
;;              - A flexible invoice: Can be paid in parts by multiple users

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant CONTRACT_OWNER 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Error constants
(define-constant ERR_INVALID_AMT (err u1001))
(define-constant ERR_INVOICE_NOT_FOUND (err u1002))
(define-constant ERR_INVOICE_ALREADY_PAID (err u1003))
(define-constant ERR_UNAUTHORIZED_PAYER (err u1004))
(define-constant ERR_SELF_PAYMENT (err u1005))
(define-constant ERR_INVALID_INVOICE_TYPE (err u1006))
(define-constant ERR_PAYMENT_EXCEEDS_BALANCE (err u1007))
(define-constant ERR_NOT_CONTRACT_OWNER (err u1008))
(define-constant ERR_AMOUNT_REQUIRED_FOR_FLEXIBLE (err u1009))

;; Success responses
(define-constant OK_INVOICE_CREATED 
    {
        message: "Invoice Created Successfully!",
        invoice-id: u0,
        amount: u0,
        sender: 'SP000000000000000000002Q6VF78,
        payer: none,
        is-paid: false,
        invoice-type: "standard"
    }
)

;; Maximum invoice amount
(define-constant MAX_INVOICE_AMOUNT u10000000000)


;; data maps
;;
(define-map invoices 
    { invoice-id: uint }
    {
        issuer: principal,
        payer: (optional principal),
        paid-amount: uint,
        amount: uint,
        paid: bool,
        invoice-type: (string-ascii 20)
    }
)

;; data vars
;;
(define-data-var last-invoice-id uint u0)
(define-data-var invoice-counter uint u0)


;; public functions
;;
(define-public (create-invoice (payer (optional principal)) (amount uint) (invoice-type (string-ascii 20)))
    (let 
        (
            (invoice-id (generate-invoice-id))
        )

        ;; Ensure only the contract owner can create invoices
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_CONTRACT_OWNER)

        ;; Ensure amount is greater than 0 and less than the max invoice amount
        (asserts! (and (> amount u0) (<= amount MAX_INVOICE_AMOUNT)) ERR_INVALID_AMT)

        ;; Ensure the invoice type is valid
        (asserts! (or (is-eq invoice-type "standard") (is-eq invoice-type "flexible")) ERR_INVALID_INVOICE_TYPE)

        ;; Ensure the payer is not the issuer for standard invoices
        (asserts! 
            (if (is-eq invoice-type "standard") 
                (and 
                    (is-some payer)
                    (not (is-eq tx-sender (unwrap! payer ERR_INVALID_AMT)))
                )
                true
            )
            ERR_SELF_PAYMENT
        )


        ;; Create the invoice
        (map-set invoices
            { invoice-id: invoice-id }
            {
                issuer: tx-sender,
                payer: payer,
                amount: amount,
                paid-amount: u0,
                paid: false,
                invoice-type: invoice-type
            }
        )

        ;; Return success response invoice details
        (ok
            (merge OK_INVOICE_CREATED
                {
                    invoice-id: invoice-id,
                    amount: amount,
                    sender: tx-sender,
                    payer: payer,
                    is-paid: false,
                    invoice-type: invoice-type
                }
            )
        )

    )
)

;; Define function to pay invoice
;;
(define-public (pay-invoice (invoice-id uint) (payment-amount (optional uint)))
    (let
        (
            (invoice (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
            (total-amount (get amount invoice))
            (paid-amount (get paid-amount invoice))
            (receiver (get issuer invoice))
            (invoice-type (get invoice-type invoice))
            (actual-payment 
                (if 
                    (is-eq invoice-type "standard")
                    total-amount
                    (unwrap! payment-amount ERR_AMOUNT_REQUIRED_FOR_FLEXIBLE)
                )
            )
        )

        ;; Ensure the invoice hasnt been fully paid yet
        (asserts! (not (get paid invoice)) ERR_INVOICE_ALREADY_PAID)

        ;; Ensure for standard invoice, ensure the payer is the one calling the function
        (asserts!
            (if 
                (is-eq invoice-type "standard")
                (is-eq tx-sender (unwrap! (get payer invoice) ERR_UNAUTHORIZED_PAYER))
                true
            )
            ERR_UNAUTHORIZED_PAYER
        )

        ;; Ensure the payment amount doesnt exceed the remaining balance for flexible invoices
        (asserts! 
            (if (is-eq invoice-type "flexible")
                (<= (+ paid-amount actual-payment) total-amount)
                true
            )
            ERR_PAYMENT_EXCEEDS_BALANCE
        )

        ;; Transfer the payment
        (try! (stx-transfer? actual-payment tx-sender receiver))

        ;; Update the Invoice
        (map-set invoices
            { invoice-id: invoice-id }
            (merge invoice {
                paid-amount: (+ paid-amount actual-payment),
                paid: (is-eq (+ paid-amount actual-payment) total-amount)
            })
        )

        ;; Return success response
        (ok
            (some
                {
                    message: "Payment processed Successfully",
                    amount-paid: payment-amount,
                    total-paid: (+ paid-amount actual-payment),
                    receiver: receiver,
                    is-fully-paid: (is-eq (+ paid-amount actual-payment) total-amount)
                }
            )
        )
    )
)

;; read only functions
;;
(define-read-only (get-invoice (invoice-id uint)) 
    (map-get? invoices { invoice-id: invoice-id })
)
;; private functions
;;
;; Define private function to get the balance of an account
(define-private (get-principal-balance (account principal)) 
    (stx-get-balance account)
)
;; Define private function to get the current time
(define-private (get-current-time)
    (default-to u0 (get-block-info? time u0))
)
;; Define private function to generate invoice id
(define-private (generate-invoice-id)
    (let
        (
            (timestamp (get-current-time))
            (counter (var-get invoice-counter))
            (last-id (var-get last-invoice-id))
            (new-id 
                (if (> timestamp u0) (+ (* timestamp u1000000) counter) (+ last-id u1))
            )
        )
        (var-set invoice-counter (mod (+ counter u1) u1000000))
        (var-set last-invoice-id new-id)
        new-id
    )
)
