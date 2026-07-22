# Fulfillment Workflows & Shipping Integration

<cite>
**Referenced Files in This Document**
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [007_stock_increment_function.sql](file://supabase/migrations/007_stock_increment_function.sql)
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)
- [send-order-notification/index.ts](file://supabase/functions/send-order-notification/index.ts)
</cite>

## Table of Contents
1. Introduction
2. Project Structure
3. Core Components
4. Architecture Overview
5. Detailed Component Analysis
6. Dependency Analysis
7. Performance Considerations
8. Troubleshooting Guide
9. Conclusion
10. Appendices

## Introduction
This document explains the end-to-end fulfillment workflow and shipping integration for the store, from stock reservation at checkout through delivery confirmation. It covers:
- Order lifecycle and fulfillment states
- Stock reservation, deduction, and release flows
- Shipping zones configuration and rate calculation logic
- Integration patterns with external shipping providers
- Tracking number management and delivery status synchronization
- Low stock alerts and operational safeguards
- Guidelines for adding new shipping providers, customizing workflows, and supporting multiple warehouses

## Project Structure
The fulfillment and shipping capabilities are implemented primarily via database migrations (schema and functions) and serverless functions that orchestrate business processes. Key areas:
- Database schema and functions for orders, fulfillment, shipping zones, and stock operations
- Serverless functions for checkout orchestration, order expiration handling, and notifications

```mermaid
graph TB
subgraph "Supabase"
DB["Database<br/>Orders, Fulfillment, Shipping Zones, Stock"]
FN_Checkout["Function: Checkout"]
FN_Cancel["Function: Cancel Expired Orders"]
FN_Notify["Function: Send Order Notification"]
end
Client["Storefront / Admin"] --> FN_Checkout
FN_Checkout --> DB
FN_Cancel --> DB
FN_Notify --> DB
```

[No sources needed since this diagram shows conceptual workflow, not actual code structure]

## Core Components
- Order fulfillment state machine and audit trail
- Shipping zones and method configuration
- Stock reservation and inventory adjustment functions
- Checkout orchestration function coordinating payment, stock, and fulfillment
- Background job to cancel expired orders and release reserved stock
- Notifications for order events

**Section sources**
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [007_stock_increment_function.sql](file://supabase/migrations/007_stock_increment_function.sql)
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)
- [send-order-notification/index.ts](file://supabase/functions/send-order-notification/index.ts)

## Architecture Overview
High-level flow from checkout to delivery:
- Checkout function validates cart, reserves stock, creates order, and triggers payment
- On successful payment, order transitions to processing and fulfillment begins
- Shipping rates are calculated based on configured zones and methods
- After dispatch, tracking numbers are recorded; statuses sync back to the system
- Delivery confirmation updates final order state

```mermaid
sequenceDiagram
participant C as "Client"
participant F as "Checkout Function"
participant DB as "Database"
participant P as "Payment Provider"
participant S as "Shipping Provider"
C->>F : "Submit checkout request"
F->>DB : "Reserve stock for items"
DB-->>F : "Reservation result"
F->>P : "Initiate payment"
P-->>F : "Payment result"
alt "Payment success"
F->>DB : "Create order and set 'processing'"
F->>DB : "Calculate shipping cost by zone/method"
DB-->>F : "Rate result"
F->>S : "Create shipment and get tracking"
S-->>F : "Tracking number"
F->>DB : "Update order with tracking"
else "Payment failed"
F->>DB : "Release reserved stock"
end
F-->>C : "Order created / next steps"
```

**Diagram sources**
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)

## Detailed Component Analysis

### Order Fulfillment Lifecycle
- States include pending, paid, processing, shipped, delivered, cancelled, refunded
- Transitions are enforced by database constraints and functions
- Audit fields capture timestamps and actor context for traceability
- Expiration policy ensures un-paid orders revert to a safe state

```mermaid
stateDiagram-v2
[*] --> Pending
Pending --> Paid : "payment success"
Paid --> Processing : "fulfillment started"
Processing --> Shipped : "dispatched"
Shipped --> Delivered : "confirmed"
Pending --> Cancelled : "expired or manual"
Paid --> Cancelled : "manual cancellation"
Processing --> Cancelled : "manual cancellation"
Shipped --> Cancelled : "manual cancellation"
Delivered --> Refunded : "refund processed"
```

**Diagram sources**
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)

**Section sources**
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)

### Shipping Zones and Methods
- Shipping zones define geographic coverage and applicable methods
- Shipping methods define pricing rules (flat, weight-based, price-based)
- Rate calculation selects matching zone and applies method formula
- Zone/method configurations can be extended without code changes

```mermaid
flowchart TD
Start(["Start"]) --> GetZone["Resolve destination to zone"]
GetZone --> HasZone{"Zone found?"}
HasZone --> |No| Error["Return error: no shipping available"]
HasZone --> |Yes| SelectMethod["Select eligible methods"]
SelectMethod --> CalcRate["Apply method pricing rule"]
CalcRate --> ReturnRate["Return shipping cost"]
Error --> End(["End"])
ReturnRate --> End
```

**Diagram sources**
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)

**Section sources**
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)

### Stock Management: Reservation, Deduction, Release
- Reservation locks stock during checkout to prevent oversell
- Deduction occurs when order is confirmed/paid
- Release happens on cancellation or expiration
- Increment function supports restocking and adjustments

```mermaid
flowchart TD
A["Checkout start"] --> R["Reserve stock"]
R --> Pay["Process payment"]
Pay --> PayOK{"Paid?"}
PayOK --> |Yes| D["Deduct stock"]
PayOK --> |No| Rel["Release reservation"]
D --> Conf["Order confirmed"]
Rel --> End(["End"])
Conf --> Ship["Ship order"]
Ship --> Track["Record tracking"]
Track --> Deliver["Mark delivered"]
Deliver --> End
```

**Diagram sources**
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [007_stock_increment_function.sql](file://supabase/migrations/007_stock_increment_function.sql)
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)

**Section sources**
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [007_stock_increment_function.sql](file://supabase/migrations/007_stock_increment_function.sql)
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)

### Checkout Orchestration
- Validates cart and calculates totals
- Reserves stock atomically
- Creates order and transitions state on payment success
- Calculates shipping cost using zones and methods
- Integrates with payment provider and records results

```mermaid
sequenceDiagram
participant C as "Client"
participant F as "Checkout Function"
participant DB as "Database"
participant P as "Payment Provider"
C->>F : "submit_checkout(cart, address)"
F->>DB : "reserve_stock(items)"
DB-->>F : "reservation_ok"
F->>P : "initiate_payment(order_total)"
P-->>F : "payment_result"
alt "success"
F->>DB : "create_order_and_set_paid()"
F->>DB : "calculate_shipping(address, items)"
DB-->>F : "shipping_cost"
F->>DB : "update_order_with_shipping()"
else "failure"
F->>DB : "release_stock(items)"
end
F-->>C : "order_id, next_steps"
```

**Diagram sources**
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)

**Section sources**
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)

### Order Expiration and Automatic Stock Release
- Unpaid orders expire after a configurable window
- Background process cancels expired orders and releases reserved stock
- Ensures inventory consistency and prevents deadlocks

```mermaid
flowchart TD
T["Timer/Cron"] --> Q["Query unpaid orders past expiry"]
Q --> Found{"Any found?"}
Found --> |No| Wait["Wait for next run"]
Found --> |Yes| Cancel["Cancel order and set reason"]
Cancel --> Rel["Release reserved stock"]
Rel --> Notify["Send notification"]
Notify --> Wait
```

**Diagram sources**
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)

**Section sources**
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)

### Notifications and Status Sync
- Sends notifications on key events (order created, shipped, delivered, cancelled)
- Can integrate with email/SMS/push channels
- Supports webhook callbacks for external systems

```mermaid
sequenceDiagram
participant DB as "Database"
participant N as "Notification Function"
participant E as "Email/SMS/Push"
DB-->>N : "Event : order.shipped"
N->>E : "Send notification payload"
E-->>N : "Delivery receipt"
N-->>DB : "Log notification event"
```

**Diagram sources**
- [send-order-notification/index.ts](file://supabase/functions/send-order-notification/index.ts)

**Section sources**
- [send-order-notification/index.ts](file://supabase/functions/send-order-notification/index.ts)

## Dependency Analysis
Key dependencies between components:
- Checkout function depends on stock reservation/deduction functions and shipping zone/methods
- Order fulfillment relies on state transitions defined in the fulfillment migration
- Expiration handler depends on order state and stock release functions
- Notifications depend on order events and user preferences

```mermaid
graph LR
Checkout["checkout/index.ts"] --> Stock["004_stock_function.sql"]
Checkout --> Zones["009_shipping_zones.sql"]
Checkout --> Fulfill["008_order_fulfillment.sql"]
Expire["cancel-expired-orders/index.ts"] --> Fulfill
Expire --> Stock
Notify["send-order-notification/index.ts"] --> Fulfill
```

**Diagram sources**
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)
- [send-order-notification/index.ts](file://supabase/functions/send-order-notification/index.ts)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)

**Section sources**
- [checkout/index.ts](file://supabase/functions/checkout/index.ts)
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)
- [send-order-notification/index.ts](file://supabase/functions/send-order-notification/index.ts)
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)

## Performance Considerations
- Use atomic database functions for stock reservation and deduction to avoid race conditions
- Keep checkout transactions short; offload heavy work (notifications, analytics) to background tasks
- Index frequently queried columns in shipping zones and orders for fast lookups
- Batch low stock checks and notifications to reduce overhead
- Cache shipping rates where appropriate, invalidating on configuration changes

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
Common issues and resolutions:
- Stock reservation failures: verify item availability and reservation limits; check stock functions for errors
- Payment timeouts: implement idempotency keys and retry policies; ensure order state remains consistent
- Shipping rate mismatches: validate zone coverage and method rules; log inputs used for rate calculation
- Tracking not updated: confirm provider webhooks or polling jobs; reconcile tracking numbers with order records
- Expired orders not cancelled: inspect cron schedule and query filters; ensure release function runs successfully

Operational tips:
- Log all state transitions and actor context
- Add alerting for failed reservations, payments, and shipping calls
- Provide admin tools to manually adjust stock and order states with audit trails

**Section sources**
- [004_stock_function.sql](file://supabase/migrations/004_stock_function.sql)
- [008_order_fulfillment.sql](file://supabase/migrations/008_order_fulfillment.sql)
- [009_shipping_zones.sql](file://supabase/migrations/009_shipping_zones.sql)
- [cancel-expired-orders/index.ts](file://supabase/functions/cancel-expired-orders/index.ts)

## Conclusion
The fulfillment and shipping subsystem combines robust database-backed state management with serverless orchestration to deliver reliable order processing. By leveraging atomic stock functions, configurable shipping zones and methods, and clear order state transitions, the system supports scalable operations and easy extensibility for additional providers and multi-warehouse scenarios.

[No sources needed since this section summarizes without analyzing specific files]

## Appendices

### Adding a New Shipping Provider
- Define provider-specific API client and mapping to internal shipping methods
- Extend rate calculation to support provider-specific rules
- Implement tracking retrieval and status sync via webhooks or polling
- Update notifications to include provider-specific details

[No sources needed since this section provides general guidance]

### Customizing Fulfillment Workflows
- Introduce new order states and transitions in the fulfillment schema
- Add middleware-like hooks in the checkout function for pre/post actions
- Ensure idempotency across retries and background jobs

[No sources needed since this section provides general guidance]

### Multi-Warehouse Support
- Add warehouse entity and link products to warehouse inventories
- Modify stock reservation to allocate per warehouse based on proximity or rules
- Adjust shipping calculations to consider warehouse location and carrier coverage
- Update reporting and low stock alerts per warehouse

[No sources needed since this section provides general guidance]