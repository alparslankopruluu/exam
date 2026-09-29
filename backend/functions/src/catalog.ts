// Server-side source of truth for what each store product grants.
// Clients never send credit amounts; they only send the verified product id.

export const CREDIT_PACKS: Record<string, number> = {
  ai_credits_small: 50,
  ai_credits_medium: 150,
  ai_credits_large: 500
};

export const PREMIUM_PRODUCTS = new Set([
  "premium_annual",
  "premium_monthly",
  // Discounted annual SKU in the same App Store subscription group, used for
  // welcome/exam offers to users who never subscribed (Apple promotional
  // offers are limited to current or lapsed subscribers).
  "premium_annual_offer"
]);
