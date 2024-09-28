
;; title: invoice
;; version:
;; summary: Smart contract to create and manage invoices
;; description: This contract allows users to create 2 types of invoices:
;;              - A standard invoice: Can be paid in fully only by a specific user
;;              - A flexible invoice: Can be paid in parts by multiple users

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
(define-constant ERR_INVALID_INVOICE_TYPE (err u1006))
(define-constant ERR_PAYMENT_EXCEEDS_BALANCE (err u1007))


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

;; (define-constant OK_INVOICE_PAID 
;;     (concat
;;         "Invoice of "
;;         (int-to-ascii amount)
;;         " paid to "
;;         (principal-to-ascii (get issuer invoice))
;;         " Successfully! New balance: "
;;         (int-to-ascii (stx-get-balance tx-sender))
;;     )
;; )

;; Maximum invoice amount
(define-constant MAX_INVOICE_AMOUNT u100000000)


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
(define-data-var next-invoice-id uint u1)

;; public functions
;;
(define-public (create-invoice (payer (optional principal)) (amount uint) (invoice-type (string-ascii 20)))
    (let 
        (
            (invoice-id (var-get next-invoice-id))
        ) 

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

        ;; Incrememnt the next invoice ID
        (var-set next-invoice-id (+ invoice-id u1))

        ;; Return success response invoice details
        (ok
            (merge OK_INVOICE_CREATED
                {
                    invoice-id: invoice-id,
                    amount: amount,
                    sender: tx-sender,
                    payer: payer, ;; defaults to 0x else payer
                    is-paid: false,
                    invoice-type: invoice-type
                }
            )
        )

    )
)

;; Define function to pay invoice
;;
(define-public (pay-invoice (invoice-id uint) (payment-amount uint))
    (let
        (
            (invoice (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
            (total-amount (get amount invoice))
            (paid-amount (get paid-amount invoice))
            (receiver (get issuer invoice))
            (invoice-type (get invoice-type invoice))
        )

        ;; Ensure the invoice hasnt been fully paid yet
        (asserts! (not (get paid invoice)) ERR_INVOICE_ALREADY_PAID)

        ;; Ensure the standard invoice, ensure the payer is the one calling the function
        (asserts! (if (is-eq invoice-type "standard")
                        (is-eq tx-sender (unwrap! (get payer invoice) ERR_UNAUTHORIZED_PAYER))
                        true
                    )
                    ERR_UNAUTHORIZED_PAYER
        )

        ;; Ensure the payment amount doesnt exceed the remaining balance
        (asserts! (<= (+ paid-amount payment-amount) total-amount) ERR_PAYMENT_EXCEEDS_BALANCE)
        
        ;; Ensure the payer is the one calling the function
        ;; (asserts! (is-eq tx-sender (get payer invoice)) ERR_UNAUTHORIZED_PAYER)

        ;; Transfer the payment
        (try! (stx-transfer? payment-amount tx-sender receiver))

        ;; Update the Invoice
        (map-set invoices
            { invoice-id: invoice-id }
            (merge invoice {
                paid-amount: (+ paid-amount payment-amount),
                paid: (is-eq (+ paid-amount payment-amount) total-amount)
            })
        )

        ;; Return success response
        (ok
            (some
                {
                    message: "Payment processed Successfully",
                    amount-paid: payment-amount,
                    total-paid: (+ paid-amount payment-amount),
                    receiver: receiver,
                    is-fully-paid: (is-eq (+ paid-amount payment-amount) total-amount)
                }
            )
        )
    )
)

        ;; ;; Mark the invoice as paid
        ;; (map-set invoices
        ;;     { invoice-id: invoice-id }
        ;;     (merge invoice { paid: true })
        ;; )


;;         ;; Calculate the new balance
;;         (let
;;             (
;;                 (new-balance (stx-get-balance tx-sender))
;;             )

;;             ;; Return success response
;;             (ok
;;                 (some
;;                     {
;;                         message: "Payment processed Successfully",
;;                         amount-paid: payment-amount,
;;                         total-paid: (+ paid-amount payment-amount),
;;                         receiver: receiver,
;;                         is-fully-paid: (is-eq (+ paid-amount payment-amount) total-amount)
;;                     }
;;                 )
;;             )
;;         )
;;     )
;; )

;; read only functions
;;
(define-read-only (get-invoice (invoice-id uint)) 
    (map-get? invoices { invoice-id: invoice-id })
)
;; private functions
;;
(define-private (get-principal-balance (account principal)) 
    (stx-get-balance account)
)