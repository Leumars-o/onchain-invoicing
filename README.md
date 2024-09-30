# Invoicing Smart Contract

## Table of Contents
- [Overview](#overview)
- [Contract Details](#contract-details)
- [Functions](#functions)
  - [Public Functions](#public-functions)
  - [Read-Only Functions](#read-only-functions)
  - [Private Functions](#private-functions)
- [Constants and Error Codes](#constants-and-error-codes)
- [Data Structures](#data-structures)
- [Usage Examples](#usage-examples)
- [Security Considerations](#security-considerations)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## Overview

This Clarity smart contract implements an invoicing system on the Stacks blockchain. It allows users to create and manage two types of invoices:

1. **Standard Invoice**: Can be paid in full only by a specific user.
2. **Flexible Invoice**: Can be paid in parts by multiple users.

The contract provides functionality for creating invoices, paying invoices, and querying invoice details.

## Contract Details

- **Name**: Invoicing Contract
- **Version**: 1.0.0
- **Description**: Smart contract to create and manage invoices
- **Contract Owner**: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`

## Functions

### Public Functions

#### `create-invoice`

Creates a new invoice.

Parameters:
- `payer`: Optional principal (required for standard invoices)
- `amount`: uint (invoice amount)
- `invoice-type`: string-ascii 20 ("standard" or "flexible")

Returns:
- OK response with invoice details or an error

#### `pay-invoice`

Pays an existing invoice.

Parameters:
- `invoice-id`: uint
- `payment-amount`: Optional uint (required for flexible invoices)

Returns:
- OK response with payment details or an error

### Read-Only Functions

#### `get-invoice`

Retrieves invoice details.

Parameters:
- `invoice-id`: uint

Returns:
- Invoice details or none if not found

### Private Functions

- `get-principal-balance`: Gets the STX balance of an account
- `get-current-time`: Gets the current block time
- `generate-invoice-id`: Generates a unique invoice ID

## Constants and Error Codes

- `MAX_INVOICE_AMOUNT`: u10000000000
- Error codes (u1001 to u1009) for various error conditions

## Data Structures

### Invoices Map

```clarity
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
```

### Data Variables

- `last-invoice-id`: Stores the last generated invoice ID
- `invoice-counter`: Counts the number of invoices created

## Usage Examples

### Creating a Standard Invoice

```clarity
(contract-call? .invoice create-invoice (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM) u100 "standard")
```

### Paying a Standard Invoice

```clarity
(contract-call? .invoice pay-invoice u1 none)
```

### Creating a Flexible Invoice

```clarity
(contract-call? .invoice create-invoice none u200 "flexible")
```

### Paying a Flexible Invoice

```clarity
(contract-call? .invoice pay-invoice u2 (some u50))
```

## Security Considerations

- Only the contract owner can create invoices
- Standard invoices can only be paid by the specified payer
- Flexible invoices can be paid by anyone, but the total paid amount cannot exceed the invoice amount
- The contract prevents self-payment for standard invoices

## Testing

To ensure the reliability and correctness of the contract, implement comprehensive unit tests covering all functions and edge cases. Use the Clarinet testing framework for Clarity smart contracts.

## Deployment

1. Ensure you have the Stacks CLI and Clarinet installed
2. Deploy the contract to the desired Stacks network (testnet or mainnet) using the Stacks CLI
3. Verify the contract deployment by checking the transaction on the Stacks Explorer

## Contributing

Contributions to improve the contract are welcome. Please follow these steps:

1. Fork the repository
2. Create a new branch for your feature
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License
