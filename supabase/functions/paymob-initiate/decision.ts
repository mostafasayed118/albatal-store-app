export type PaymobClaim = {
  ok: boolean;
  code: string;
  payment_id?: string;
  claim_token?: string;
  paymob_order_id?: string;
  amount?: number;
};

export type InitiationDecision =
  | { kind: "reject"; status: 400; message: string }
  | { kind: "reissue"; paymobOrderId: string; amount: number }
  | { kind: "in_progress"; status: 409; message: string }
  | { kind: "create"; paymentId: string; claimToken: string; amount: number }
  | { kind: "error"; status: 500; message: string };

export function decideInitiationClaim(
  orderPaymentMethod: string,
  claim: PaymobClaim | null,
): InitiationDecision {
  if (orderPaymentMethod !== "paymob_card") {
    return {
      kind: "reject",
      status: 400,
      message: "Unsupported payment method",
    };
  }

  if (claim === null) {
    return {
      kind: "error",
      status: 500,
      message: "Failed to initialize payment",
    };
  }

  if (claim.code === "unsupported_payment_method") {
    return {
      kind: "reject",
      status: 400,
      message: "Unsupported payment method",
    };
  }

  if (!claim.ok) {
    return {
      kind: "reject",
      status: 400,
      message: "Order is not eligible for payment",
    };
  }

  if (
    claim.code === "existing_provider_order" &&
    typeof claim.paymob_order_id === "string" &&
    typeof claim.amount === "number" &&
    Number.isFinite(claim.amount)
  ) {
    return {
      kind: "reissue",
      paymobOrderId: claim.paymob_order_id,
      amount: claim.amount,
    };
  }

  if (claim.code === "initiation_in_progress") {
    return {
      kind: "in_progress",
      status: 409,
      message: "Payment initiation already in progress",
    };
  }

  if (
    claim.code === "claimed" &&
    typeof claim.payment_id === "string" &&
    typeof claim.claim_token === "string" &&
    typeof claim.amount === "number" &&
    Number.isFinite(claim.amount)
  ) {
    return {
      kind: "create",
      paymentId: claim.payment_id,
      claimToken: claim.claim_token,
      amount: claim.amount,
    };
  }

  return {
    kind: "error",
    status: 500,
    message: "Failed to initialize payment",
  };
}
