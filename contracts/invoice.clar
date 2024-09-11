
;; title: invoice
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;


;; data maps
;;
(define-map invoices 
    { invoice-id: uint }
    {
        issuer: principal,
        payer: principal,
        amount: uint,
        paid: bool
    }
)

;; data vars
;;
(define-data-var next-invoice-id uint u1)

;; public functions
;;
(define-public (create-invoice (payer principal) (amount uint))
    (let 
        (
            (invoice-id (var-get next-invoice-id))
        ) 

        ;; Ensure amount is greater than zero
        (asserts! (> amount u0) (err u1))

        ;; Create the invoice
        (map-set invoices
            { invoice-id: invoice-id }
            {
                issuer: tx-sender,
                payer: payer,
                amount: amount,
                paid: false
            }
        )

        ;; Incrememnt the next invoice ID
        (var-set next-invoice-id (+ invoice-id u1))

        ;; Return success with the created invoice
        (ok invoice-id)
    )
)

;; Define function to pay invoice
;;
(define-public (pay-invoice (invoice-id uint))
    (let 
        (
            (invoice (unwrap! (map-get? invoices { invoice-id: invoice-id }) (err u2)))
            (amount (get amount invoice))
        )

        ;; Ensure the incoice hasnt been paid yet
        (asserts! (not (get paid invoice)) (err u3))

        ;; Ensure the payer is the one calling the function
        (asserts! (is-eq tx-sender (get payer invoice)) (err u4))

        ;; Transfer the payment
        (try! (stx-transfer? amount tx-sender (get issuer invoice)))

        ;; Mark the invoice as paid
        (map-set invoices
            { invoice-id: invoice-id }
            (merge invoice { paid: true})
        )

        ;; Return success
        (ok true)
    )
)
;; read only functions
;;
(define-read-only (get-invoice (invoice-id uint)) 
    (map-get? invoices { invoice-id: invoice-id })
)

;; private functions
;;

