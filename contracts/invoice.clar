
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

;; Error constants
(define-constant ERR_INVALID_AMT (err u1001))
(define-constant ERR_INVOICE_NOT_FOUND (err u1002))
(define-constant ERR_INVOICE_ALREADY_PAID (err u1003))
(define-constant ERR_UNAUTHORIZED_PAYER (err u1004))
(define-constant ERR_SELF_PAYMENT (err u1005))

;; Success constants
;; (define-constant OK_INVOICE_CREATED 
;;     (ok 
;;         {
;;             code: u2001,
;;             message: "Invoice Created!",
;;             invoice-id: u0, ;; placeholder
;;             amount: u0,     ;; placeholder
;;             sender: u0,     ;; placeholder
;;             payer: 0x       ;; placeholder
;;         }
;;     )
;; )

(define-constant OK_INVOICE_CREATED 
    {
        message: "Invoice Created Successfully!",
        invoice-id: u0, ;; placeholder
        amount: u0,     ;; placeholder
        sender: 0x,     ;; placeholder
        payer: 0x,       ;; placeholder
        is-paid: false  ;; placeholder
    }
)

(define-constant OK_INVOICE_PAID 
    (ok 
        {
            message: "Invoice paid! Your new balance is:",
            balance: (stx-get-balance tx-sender)
        }
    )
)

;; Maximum invoice amount
(define-constant MAX_INVOICE_AMOUNT u1000000)


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

        ;; Ensure amount is greater than 0 and less than the max invoice amount
        (asserts! (and (> amount u0) (<= amount MAX_INVOICE_AMOUNT)) ERR_INVALID_AMT)

        ;; Ensure the payer is not the issuer
        (asserts! (not (is-eq tx-sender payer)) ERR_SELF_PAYMENT)

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

        ;; Return success response invoice details
        (ok
            (merge OK_INVOICE_CREATED
                {
                    invoice-id: invoice-id,
                    amount: amount,
                    sender: tx-sender,
                    payer: payer,
                    is-paid: false
                }
            )
        )

    )
)

;; Define function to pay invoice
;;
(define-public (pay-invoice (invoice-id uint))
    (let 
        (
            (invoice (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
            (amount (get amount invoice))
        )

        ;; Ensure the incoice hasnt been paid yet
        (asserts! (not (get paid invoice)) ERR_INVOICE_ALREADY_PAID)

        ;; Ensure the payer is the one calling the function
        (asserts! (is-eq tx-sender (get payer invoice)) ERR_UNAUTHORIZED_PAYER)

        ;; Transfer the payment
        (try! (stx-transfer? amount tx-sender (get issuer invoice)))

        ;; Mark the invoice as paid
        (map-set invoices
            { invoice-id: invoice-id }
            (merge invoice { paid: true})
        )

        ;; Return success
        OK_INVOICE_PAID
    )
)
;; read only functions
;;
(define-read-only (get-invoice (invoice-id uint)) 
    (map-get? invoices { invoice-id: invoice-id })
)

;; private functions
;;
;; (define-private (create-invoice-success (invoice-id uint) (sender principal) (payer principal))
;;     (ok
;;         (merge (unwrap-panic OK_INVOICE_CREATED)
;;             {
;;                 invoice-id: invoice-id,
;;                 sender: sender,
;;                 payer: payer
;;             }
;;         )
;;     )
;; )